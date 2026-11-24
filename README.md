# Pong-Garagem

Computador de 8 bits com CPU própria (GAR-8) na Sipeed Tang Nano 20K.
ISA, mapas de memória e de E/S, e protocolo do bootloader: [docs/isa.md](docs/isa.md).

## Estrutura

| Pasta | Conteúdo |
|-------|----------|
| `rtl/` | CPU (`gar8_cpu.v`), SoC (`gar8_soc.v`), vídeo (`gar8_video.v`, `tmds_enc.v`, `hdmi_gowin.v`), som (`gar8_som.v`), topo da placa |
| `sw/`  | montador (`gasm.py`), bootloader (`boot.asm`), SO (`os.asm`), carregador serial (`carregar.py`), teste de vídeo/som/botões (`teste_video.asm`) |
| `tb/`  | testbenches do Icarus: CPU, bootloader, TMDS e vídeo/som/botões |
| `placa/` | pinos da Tang Nano 20K; `led_branco/` é o primeiro teste da placa |

## Uso

Requisitos: OSS CAD Suite em `C:\oss-cad-suite`, Python 3 com `pyserial`.

```
python build.py sim               # monta e roda os testes (~2 min; todos terminam com OK)
                                  # e grava build/quadro.png, a tela que o HDMI mostraria
python build.py placa             # gera build/pong_garagem.fs
python build.py gravar            # grava na SRAM (some ao desligar)
python build.py gravar --flash    # grava na flash
python sw/gasm.py prog.asm prog.bin
python sw/carregar.py COM4 prog.bin --reset   # grava, espera o boot e envia prog.bin
python sw/carregar.py COM4                    # só mostra a serial
python sw/carregar.py COM4 build/teste_video.bin --reset   # teste das fases 4, 5 e 6
```

Testes na placa e ligação dos botões na protoboard: [docs/roteiro_placa.md](docs/roteiro_placa.md).

A serial da placa é a segunda porta da Tang Nano (aqui, COM4), 9600 8N1.
**Abra a serial só depois de gravar**: a ponte USB trava a porta que estiver
aberta durante a gravação JTAG (se travar, desconecte e reconecte o cabo).
