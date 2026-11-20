; Bootloader da GAR-8 — ROM 0000h (máximo 256 bytes)
; 1. ajusta a pilha, desliga som e LEDs, pisca os LEDs 3 vezes
; 2. copia o SO da ROM (0100h) para a RAM (8000h)
; 3. envia "GAR-8 boot" e espera 'S' pela serial por 2 s
; 4. com 'S': recebe tamanho, bytes e soma; certo -> 'K', errado -> 'E' e reinicia
; 5. pula para o SO em 8000h
; Protocolo completo em docs/isa.md.

SER_ST  EQU $01         ; bit 0 = byte chegou, bit 1 = transmissor ocupado
SER_DAT EQU $02
LEDS    EQU $03         ; OUT
TICK    EQU $03         ; IN: +1 a cada 10 ms
SOM     EQU $8A

OS_ROM  EQU $0100
OS_RAM  EQU $8000
OS_LEN  EQU $0700       ; tamanho da imagem na ROM
OS_MAX  EQU $0800       ; maior carga aceita pela serial

LEN     EQU $8800       ; variáveis (área de programa, livre durante o boot)
SUM     EQU $8802
T0      EQU $8803

        ORG 0
inicio: LDSP #$C000
        LDA #0
        OUT SOM
        OUT LEDS

        LDX #3                  ; sinal de vida
pisca:  LDA #$3F
        OUT LEDS
        CALL espera
        LDA #0
        OUT LEDS
        CALL espera
        DEX
        JNZ pisca

        LDX #0                  ; copia o SO para a RAM
copia:  LDA OS_ROM,X
        STA OS_RAM,X
        INX
        CPX #OS_LEN
        JNZ copia

        LDX #msg
        CALL puts

        IN TICK                 ; janela de 2 s
        STA T0
janela: IN SER_ST
        AND #1
        JNZ chegou
        IN TICK
        SUB T0
        CMP #200
        JC janela
        JMP OS_RAM

chegou: IN SER_DAT
        CMP #'S'
        JNZ janela              ; ignora outros bytes
        LDA #'>'
        CALL putc

        CALL getc               ; tamanho, little-endian
        STA LEN
        TAXL
        CALL getc
        STA LEN+1
        TAXH
        CPX #OS_MAX+1           ; tamanho > OS_MAX -> erro
        JNC erro

        LDA #0
        STA SUM
        LDX #0
recebe: TXLA                    ; X == LEN ?
        CMP LEN
        JNZ mais
        TXHA
        CMP LEN+1
        JZ fim
mais:   CALL getc
        STA OS_RAM,X
        ADD SUM
        STA SUM
        INX
        JMP recebe

fim:    CALL getc               ; soma enviada pelo PC
        CMP SUM
        JNZ erro
        LDA #'K'
        CALL putc
        JMP OS_RAM

erro:   LDA #'E'
        CALL putc
        JMP inicio              ; recomeça e recopia o SO da ROM

; ---- sub-rotinas ----
getc:   IN SER_ST               ; A = próximo byte da serial
        AND #1
        JZ getc
        IN SER_DAT
        RET

putc:   PUSH                    ; envia A
putc1:  IN SER_ST
        AND #2
        JNZ putc1
        POP
        OUT SER_DAT
        RET

puts:   LDA 0,X                 ; envia o texto em X até o byte 0
        JZ puts1
        CALL putc
        INX
        JMP puts
puts1:  RET

espera: IN TICK                 ; 100 ms
        STA T0
esp1:   IN TICK
        SUB T0
        CMP #10
        JC esp1
        RET

msg:    DB "GAR-8 boot",13,10,0
