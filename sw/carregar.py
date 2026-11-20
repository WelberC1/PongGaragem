"""Carrega um programa na GAR-8 pelo bootloader (protocolo em docs/isa.md).

    python sw/carregar.py COM4                   só mostra o que a placa envia
    python sw/carregar.py COM4 programa.bin      espera o boot e envia o programa
    --reset   regrava a SRAM da placa para provocar o reset (em vez de apertar S1)
"""
import os
import subprocess
import sys
import time

import serial

OS_MAX = 0x800


def le_ate(porta, alvo, segundos):
    """Lê e mostra a serial até aparecer alvo; devolve True se apareceu."""
    buf, fim = b'', time.time() + segundos
    while time.time() < fim:
        b = porta.read(64)
        if b:
            sys.stdout.write(b.decode('latin-1'))
            sys.stdout.flush()
            buf += b
            if alvo and alvo in buf:
                return True
    return False


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args:
        sys.exit(__doc__)
    dados = None
    if len(args) > 1:
        with open(args[1], 'rb') as f:
            dados = f.read()
        if not 0 < len(dados) <= OS_MAX:
            sys.exit(f'{args[1]}: {len(dados)} bytes; precisa ter de 1 a {OS_MAX}')

    if '--reset' in sys.argv:
        # grava antes de abrir a porta: a ponte USB (BL616) trava a serial
        # que estiver aberta durante a gravação JTAG
        raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        subprocess.run([sys.executable, os.path.join(raiz, 'build.py'), 'gravar'],
                       stdout=subprocess.DEVNULL, check=True)
    with serial.Serial(args[0], 9600, timeout=0.05) as porta:
        if '--reset' not in sys.argv:
            print('Aperte S1 na placa (reset)...')
        if dados is None:
            le_ate(porta, None, 3600)
            return
        if not le_ate(porta, b'GAR-8 boot\r\n', 60):
            sys.exit('\nnão vi o bootloader')
        porta.write(b'S')
        if not le_ate(porta, b'>', 1):
            sys.exit('\nbootloader não respondeu ao S')
        porta.write(bytes([len(dados) & 0xFF, len(dados) >> 8]) + dados + bytes([sum(dados) & 0xFF]))
        if not le_ate(porta, b'K', len(dados) / 900 + 2):
            sys.exit('\ncarga recusada')
        print(f'\n[{len(dados)} bytes carregados]')
        le_ate(porta, None, 2)


if __name__ == '__main__':
    main()
