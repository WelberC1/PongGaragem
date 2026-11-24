# GAR-8 — conjunto de instruções

CPU de 8 bits, acumulador, endereços de 16 bits. Instrução = 1 byte de opcode
+ 0, 1 ou 2 bytes de operando. Endereços de 16 bits ficam em little-endian
(byte baixo primeiro).

## Registradores

| Reg | Bits | Uso |
|-----|------|-----|
| A   | 8  | acumulador: toda conta passa por ele |
| X   | 16 | índice (`LDA end,X`), contador, ponteiro |
| SP  | 16 | pilha; cresce para baixo; `PUSH` faz `SP-1` e grava |
| PC  | 16 | contador de programa; começa em 0000h no reset |
| Z   | 1  | resultado = 0 |
| C   | 1  | vai-um (ADD), empresta (SUB/CMP: A < operando), bit que saiu (SHL/SHR) |

## Instruções

`#n` = imediato de 8 bits, `#nn` = imediato de 16 bits, `a` = endereço de 16 bits,
`a,X` = endereço + X, `p` = porta de E/S (8 bits).

| Opcode | Instrução | Bytes | Efeito | Flags |
|--------|-----------|-------|--------|-------|
| 00 | NOP       | 1 | nada | – |
| 01 | HLT       | 1 | para a CPU | – |
| 10 | LDA #n    | 2 | A = n | Z |
| 11 | LDA a     | 3 | A = M[a] | Z |
| 12 | LDA a,X   | 3 | A = M[a+X] | Z |
| 13 | STA a     | 3 | M[a] = A | – |
| 14 | STA a,X   | 3 | M[a+X] = A | – |
| 20 / 21 | ADD #n / a | 2 / 3 | A = A + op | Z C |
| 22 / 23 | SUB #n / a | 2 / 3 | A = A − op | Z C |
| 24 / 25 | AND #n / a | 2 / 3 | A = A and op | Z |
| 26 / 27 | OR #n / a  | 2 / 3 | A = A or op | Z |
| 28 / 29 | XOR #n / a | 2 / 3 | A = A xor op | Z |
| 2A / 2B | CMP #n / a | 2 / 3 | calcula A − op, não guarda | Z C |
| 2C | SHL       | 1 | A = A << 1 | Z C |
| 2D | SHR       | 1 | A = A >> 1 | Z C |
| 30 | LDX #nn   | 3 | X = nn | – |
| 31 | INX       | 1 | X = X + 1 | Z |
| 32 | DEX       | 1 | X = X − 1 | Z |
| 33 | CPX #nn   | 3 | compara X com nn | Z C |
| 34 | TAXL      | 1 | X[7:0] = A | – |
| 35 | TAXH      | 1 | X[15:8] = A | – |
| 36 | TXLA      | 1 | A = X[7:0] | Z |
| 37 | TXHA      | 1 | A = X[15:8] | Z |
| 40 | JMP a     | 3 | PC = a | – |
| 41 | JZ a      | 3 | se Z | – |
| 42 | JNZ a     | 3 | se não Z | – |
| 43 | JC a      | 3 | se C | – |
| 44 | JNC a     | 3 | se não C | – |
| 45 | JPX       | 1 | PC = X | – |
| 46 | CALL a    | 3 | empilha PC, PC = a | – |
| 47 | RET       | 1 | desempilha PC | – |
| 48 | PUSH      | 1 | empilha A | – |
| 49 | POP       | 1 | desempilha A | Z |
| 4A | PHX       | 1 | empilha X | – |
| 4B | PLX       | 1 | desempilha X | – |
| 4C | LDSP #nn  | 3 | SP = nn | – |
| 50 | IN p      | 2 | A = porta p | Z |
| 51 | OUT p     | 2 | porta p = A | – |

Opcode não listado: a CPU para (como HLT), para o erro aparecer logo.

## Mapa de memória

| Endereço | Uso |
|----------|-----|
| 0000h–00FFh | ROM: bootloader |
| 0100h–07FFh | ROM: imagem do SO (montada para rodar em 8000h) |
| 8000h–87FFh | RAM: SO em execução |
| 8800h–BFFFh | RAM: programa, dados e pilha (SP inicial = C000h) |

A15 = 0 seleciona a ROM, A15 = 1 a RAM.

## Portas de E/S

| Porta | IN | OUT |
|-------|----|-----|
| 00h | botões, 1 = apertado (lidos a cada 10 ms): bit 0 = S2 da placa, 1 = J1 sobe, 2 = J1 desce, 3 = J2 sobe, 4 = J2 desce | – |
| 01h | serial: bit 0 = byte recebido, bit 1 = transmissor ocupado | – |
| 02h | lê o byte recebido (limpa o bit 0 da porta 01h) | envia um byte |
| 03h | contador de tempo, +1 a cada 10 ms | LEDs da placa (bits 0–5) |
| 80h | – | bola X (casa 0–159) |
| 81h | – | bola Y (casa 0–119) |
| 82h | – | raquete 1 Y (topo; 0–104) |
| 83h | – | raquete 2 Y (topo; 0–104) |
| 84h | – | placar jogador 1 (0–99) |
| 85h | – | placar jogador 2 (0–99) |
| 86h | – | cor da frente, RRRGGGBB (início FFh = branco) |
| 87h | bit 0 = quadro novo (começou o retraço vertical, 60 vezes/s); ler limpa | – |
| 88h | – | duração do som, em unidades de 10 ms (início 10 = 100 ms) |
| 8Ah | – | toca a nota n: frequência = 23 437 / n Hz (n = 53 ≈ 440 Hz); 0 cala |

### Vídeo

640×480 a 60 Hz pelo HDMI. A tela é uma grade de 160×120 casas de 4×4 pixels.
A CPU só escreve as posições; o circuito desenha:

| Objeto | Tamanho (casas) | Posição |
|--------|-----------------|---------|
| bola | 2×2 | canto de cima à esquerda em (80h, 81h) |
| raquete 1 | 2×16 | colunas 4–5, topo em 82h |
| raquete 2 | 2×16 | colunas 154–155, topo em 83h |
| rede | 1 coluna tracejada | coluna 79 |
| placares | 2 dígitos de 6×10 | colunas 58 e 88, linha 4 |

Escreva nas portas logo depois de ver o bit 0 da 87h ligado: assim a imagem
não muda no meio da tela.

## Ciclos

Cada estado dura um ciclo de 3 MHz. Busca do opcode: 2 estados; cada byte de
operando: +1; execução: +1; leitura de memória, CALL, PHX: +1; RET, PLX: +2.
Ex.: `NOP` = 3 estados (1 µs), `LDA a,X` = 6 estados (2 µs).

## Protocolo do bootloader (serial 9600 8N1)

1. Depois do reset o bootloader pisca os LEDs, copia o SO da ROM para a RAM e
   envia `GAR-8 boot\r\n`.
2. Se receber `S` em até 2 s, responde `>`. Senão, pula para 8000h.
3. O PC envia: tamanho (2 bytes, little-endian, no máximo 0800h), os bytes, e a
   soma de verificação (soma de todos os bytes, módulo 256).
4. Resposta `K`: soma certa, pula para 8000h. Resposta `E`: erro, o bootloader
   reinicia e usa o SO da ROM.
