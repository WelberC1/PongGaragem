# Roteiro de testes na placa

Quem está com a Tang Nano 20K segue este roteiro e anota o resultado no fim
do arquivo (data, o que funcionou, foto ou vídeo se der).

## 1. Preparar o computador (uma vez)

1. Instalar o Git e clonar o repositório:
   `git clone https://github.com/WelberC1/PongGaragem.git`
2. Baixar o **OSS CAD Suite** para Windows
   (github.com/YosysHQ/oss-cad-suite-build/releases, arquivo `windows-x64`) e
   extrair em `C:\oss-cad-suite`.
3. Instalar o Python 3 e depois `pip install pyserial`.
4. Driver da placa: na primeira gravação o Windows pode não achar o
   gravador. Use o **Zadig** para trocar o driver da "Interface 0" da placa
   para **WinUSB** (só a interface 0; a 1 é a serial e fica como está).
5. Descobrir a porta serial no Gerenciador de Dispositivos (no notebook do
   Welber era a COM4) e usar esse número nos comandos abaixo.

Conferir: `python build.py sim` deve mostrar 4 linhas `OK:` e criar
`build/quadro.png`.

## 2. Gravar e carregar o teste

```
python build.py placa      # gera o circuito (~1 min)
python build.py gravar     # grava na placa (some ao desligar)
python sw/carregar.py COM4 build/teste_video.bin --reset
```

**Não abra o PuTTY enquanto grava**: a serial trava. Se travar, tire e
ponha o cabo USB de volta.

## 3. Botões na protoboard (fase 6)

Não precisa de resistor: o pull-up está ligado dentro da FPGA.
Cada botão tem um lado no pino e o outro no **GND**.

| Botão | Pino da placa | Lado da placa |
|-------|---------------|---------------|
| Jogador 1 sobe  | 73 | esquerdo, 1º pino de cima |
| Jogador 1 desce | 74 | esquerdo, 2º pino |
| Jogador 2 sobe  | 72 | direito, abaixo do 3V3 |
| Jogador 2 desce | 71 | direito, logo abaixo do 72 |
| GND | GND | esquerdo embaixo ou direito (há vários) |

⚠️ **Nunca ligue um botão no 3V3 ou no 5V**: o pino seria ligado direto na
alimentação quando o botão fosse apertado.

## 4. Checklist

Com o `teste_video.bin` rodando:

| Fase | Teste | Pronto quando | Resultado |
|------|-------|---------------|-----------|
| 6 | Apertar cada botão | acende um LED diferente: S2 = LED 0, J1 sobe = 1, J1 desce = 2, J2 sobe = 3, J2 desce = 4 | |
| 4 | Ligar o HDMI num monitor/TV | aparece a tela de `build/quadro.png`: rede, placares e raquetes | |
| 4 | Olhar a bola | anda sozinha e quica nas bordas | |
| 4 | Botões | as raquetes sobem e descem | |
| 4 | Placar | conta os quiques (esquerda/direita no placar 1, cima/baixo no 2) | |
| 5 | Alto-falante no conector da placa | bip agudo nos quiques laterais, grave em cima/embaixo; o bip para sozinho | |

### Se algo não funcionar

| Sintoma | O que tentar |
|---------|--------------|
| monitor diz "sem sinal" | outro monitor ou TV (alguns não aceitam 640×480); outro cabo; mandar foto para o Welber |
| tela aparece mas treme ou com cores erradas | anotar e mandar foto: é ajuste no `hdmi_gowin.v` |
| LEDs não acendem com os botões | conferir se o outro lado do botão está no GND e o número do pino |
| sem som | conferir o alto-falante no conector da placa; testar com outro alto-falante de 8 Ω |
| `carregar.py` não acha a placa | fechar o PuTTY; trocar COM4 pelo número certo; reconectar o USB |

## 5. Registro

| Data | Quem | Teste | Resultado |
|------|------|-------|-----------|
| | | | |
