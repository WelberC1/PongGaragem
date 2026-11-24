; Teste das fases 4, 5 e 6 (vídeo, som e botões), carregado pela serial em 8000h:
;   python sw/carregar.py COM4 build/teste_video.bin --reset
; - a bola quica nas bordas e anda 1 casa por quadro (60 por segundo)
; - quique na esquerda/direita: bip agudo e +1 no placar 1; em cima/embaixo: bip grave e +1 no placar 2
; - os botões movem as raquetes e acendem os LEDs (LED 0 = S2, 1-4 = botões)
; Portas: docs/isa.md.

BOTOES  EQU $00
LEDS    EQU $03
BOLA_X  EQU $80
BOLA_Y  EQU $81
RAQ1    EQU $82
RAQ2    EQU $83
PLACAR1 EQU $84
PLACAR2 EQU $85
QUADRO  EQU $87
SOM     EQU $8A

AGUDO   EQU 53          ; 23437 / 53 = 442 Hz
GRAVE   EQU 106         ; 221 Hz
RAQ_MAX EQU 104         ; 120 linhas - 16 da raquete

BX      EQU $8800       ; variáveis
BY      EQU $8801
VX      EQU $8802       ; +1 ou -1 ($FF)
VY      EQU $8803
R1      EQU $8804
R2      EQU $8805
P1      EQU $8806
P2      EQU $8807
BT      EQU $8808

        ORG $8000
        LDSP #$C000
        LDA #3
        STA BX
        LDA #2
        STA BY
        LDA #$FF
        STA VX
        STA VY
        LDA #52
        STA R1
        STA R2
        LDA #0
        STA P1
        STA P2

laco:   IN QUADRO               ; espera o quadro novo
        AND #1
        JZ laco

        IN BOTOES
        STA BT
        OUT LEDS

        LDA BT                  ; jogador 1
        AND #%00010
        JZ j1b
        LDA R1
        JZ j1b
        SUB #1
        STA R1
j1b:    LDA BT
        AND #%00100
        JZ j2
        LDA R1
        CMP #RAQ_MAX
        JNC j2
        ADD #1
        STA R1

j2:     LDA BT                  ; jogador 2
        AND #%01000
        JZ j2b
        LDA R2
        JZ j2b
        SUB #1
        STA R2
j2b:    LDA BT
        AND #%10000
        JZ bola
        LDA R2
        CMP #RAQ_MAX
        JNC bola
        ADD #1
        STA R2

bola:   LDA BX                  ; X
        ADD VX
        STA BX
        JZ batex
        CMP #158
        JNZ eixoy
batex:  LDA VX
        XOR #$FF
        ADD #1
        STA VX
        LDA P1
        ADD #1
        STA P1
        LDA #AGUDO
        OUT SOM

eixoy:  LDA BY                  ; Y
        ADD VY
        STA BY
        JZ batey
        CMP #118
        JNZ mostra
batey:  LDA VY
        XOR #$FF
        ADD #1
        STA VY
        LDA P2
        ADD #1
        STA P2
        LDA #GRAVE
        OUT SOM

mostra: LDA BX
        OUT BOLA_X
        LDA BY
        OUT BOLA_Y
        LDA R1
        OUT RAQ1
        LDA R2
        OUT RAQ2
        LDA P1
        OUT PLACAR1
        LDA P2
        OUT PLACAR2
        JMP laco
