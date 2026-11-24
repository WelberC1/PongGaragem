"""Constrói o Pong-Garagem.

    python build.py sim              monta o software e roda os testes no Icarus
                                     (o teste de vídeo grava build/quadro.png)
    python build.py placa            gera build/pong_garagem.fs para a Tang Nano 20K
    python build.py gravar           grava na SRAM da placa (perde ao desligar)
    python build.py gravar --flash   grava na flash (fica gravado)
"""
import os
import shutil
import subprocess
import struct
import sys
import zlib

RAIZ = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(RAIZ, 'build')
sys.path.insert(0, os.path.join(RAIZ, 'sw'))
import gasm  # noqa: E402

OSS = r'C:\oss-cad-suite'
if not shutil.which('yosys') and os.path.isdir(OSS):
    os.environ['PATH'] = os.pathsep.join([os.path.join(OSS, 'bin'), os.path.join(OSS, 'lib'), os.environ['PATH']])

RTL = [os.path.join(RAIZ, 'rtl', f) for f in ('gar8_cpu.v', 'gar8_soc.v', 'gar8_video.v', 'gar8_som.v', 'tmds_enc.v')]
PLACA = [os.path.join(RAIZ, 'rtl', f) for f in ('hdmi_gowin.v', 'top_tangnano20k.v')]


def run(*cmd):
    print('>', ' '.join(cmd))
    subprocess.run(cmd, cwd=BUILD, check=True)


def hexfile(nome, dados):
    with open(os.path.join(BUILD, nome), 'w') as f:
        f.write('\n'.join(f'{b:02x}' for b in dados) + '\n')


def monta(arq, org):
    o, img = gasm.assemble_file(os.path.join(RAIZ, 'sw', arq))
    assert o == org, f'{arq}: começa em {o:04X}h, esperado {org:04X}h'
    return img


def software():
    os.makedirs(BUILD, exist_ok=True)
    boot, so = monta('boot.asm', 0), monta('os.asm', 0x8000)
    assert len(boot) <= 0x100, f'bootloader com {len(boot)} bytes, máximo 256'
    assert len(so) <= 0x700, f'SO com {len(so)} bytes, máximo 1792'
    rom = boot.ljust(0x100, b'\0') + so
    hexfile('rom.hex', rom.ljust(0x800, b'\0'))
    print(f'ROM: bootloader {len(boot)} bytes, SO {len(so)} bytes')

    hexfile('teste_cpu.hex', monta('teste_cpu.asm', 0).ljust(0x800, b'\0'))
    carga = monta('teste_carga.asm', 0x8000)
    hexfile('carga.hex', carga)
    with open(os.path.join(BUILD, 'carga.vh'), 'w') as f:
        f.write(f'`define CARGA_LEN {len(carga)}\n`define CARGA_SUM 8\'h{sum(carga) & 0xFF:02x}\n')

    video = monta('teste_video.asm', 0x8000)
    hexfile('teste_video.hex', video)
    with open(os.path.join(BUILD, 'teste_video.bin'), 'wb') as f:   # para o carregar.py
        f.write(video)
    hexfile('salto.hex', bytes([0x40, 0x00, 0x80]).ljust(0x800, b'\0'))   # ROM: JMP $8000


def ppm_para_png(ppm, png):
    """Converte o P3 que o tb_video grava num PNG, para abrir no Windows."""
    with open(ppm) as f:
        v = f.read().split()
    w, h = int(v[1]), int(v[2])
    pix = bytes(int(x) for x in v[4:4 + w * h * 3])
    linhas = b''.join(b'\0' + pix[y * w * 3:(y + 1) * w * 3] for y in range(h))

    def bloco(tipo, dados):
        return struct.pack('>I', len(dados)) + tipo + dados + struct.pack('>I', zlib.crc32(tipo + dados))
    with open(png, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + bloco(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                + bloco(b'IDAT', zlib.compress(linhas)) + bloco(b'IEND', b''))


def sim():
    software()
    import emulador
    emulador.autoteste()
    for tb in ('tb_cpu', 'tb_boot', 'tb_tmds', 'tb_video'):
        run('iverilog', '-g2005', '-o', tb + '.vvp', os.path.join(RAIZ, 'tb', tb + '.v'), *RTL)
        saida = subprocess.run(['vvp', '-n', tb + '.vvp'], cwd=BUILD, capture_output=True, text=True).stdout
        print(saida)
        if 'OK:' not in saida:
            sys.exit(f'{tb} falhou')
    ppm_para_png(os.path.join(BUILD, 'quadro.ppm'), os.path.join(BUILD, 'quadro.png'))
    print('quadro do teste de vídeo: build/quadro.png')


def placa():
    software()
    run('yosys', '-q', '-p', 'read_verilog ' + ' '.join(RTL + PLACA)
        + '; synth_gowin -top top_tangnano20k -json pong_garagem.json')
    run('nextpnr-himbaechel', '-q', '--json', 'pong_garagem.json', '--write', 'pnr.json',
        '--device', 'GW2AR-LV18QN88C8/I7', '--vopt', 'family=GW2A-18C',
        '--vopt', 'cst=' + os.path.join(RAIZ, 'placa', 'tangnano20k.cst'))
    run('gowin_pack', '-d', 'GW2A-18C', '-o', 'pong_garagem.fs', 'pnr.json')


def gravar(flash):
    run('openFPGALoader', '-b', 'tangnano20k', *(['-f'] if flash else []), 'pong_garagem.fs')


if __name__ == '__main__':
    acao = sys.argv[1] if len(sys.argv) > 1 else ''
    if acao == 'sim':
        sim()
    elif acao == 'placa':
        placa()
    elif acao == 'gravar':
        gravar('--flash' in sys.argv)
    else:
        sys.exit(__doc__)
