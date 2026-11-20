; Teste de todas as instruções da GAR-8. Roda como ROM inteira (ORG 0).
; Resultado na porta F0h: 55h = passou, EEh = falhou (o testbench mostra o PC).
RES     EQU $F0

        ORG 0
        LDSP #$C000
        LDA #0                  ; LDA / Z
        JNZ falha
        LDA #$5A
        JZ falha
        CMP #$5A
        JNZ falha

        LDA #$F0                ; ADD com vai-um
        ADD #$20
        JNC falha
        CMP #$10
        JNZ falha
        LDA #$10                ; SUB com empresta
        SUB #$20
        JNC falha
        CMP #$F0
        JNZ falha
        LDA #5                  ; CMP: C = (A < op)
        CMP #6
        JNC falha
        CMP #5
        JC falha

        LDA #$F0                ; lógicas
        AND #$3C
        CMP #$30
        JNZ falha
        OR #$0F
        CMP #$3F
        JNZ falha
        XOR #$FF
        CMP #$C0
        JNZ falha

        LDA #$81                ; deslocamentos
        SHL
        JNC falha
        CMP #$02
        JNZ falha
        SHR
        JC falha
        SHR
        JNC falha
        JNZ falha

        LDA #$33                ; memória
        STA $8000
        LDA #0
        LDA $8000
        CMP #$33
        JNZ falha
        LDA #$11
        ADD $8000               ; 44
        SUB $8000               ; 11
        AND $8000               ; 11
        OR $8000                ; 33
        XOR $8000               ; 00
        JNZ falha
        LDA #$44
        CMP $8000
        JC falha
        JZ falha

        LDX #$0010              ; X e indexado
        LDA #$77
        STA $8000,X
        LDA $8010
        CMP #$77
        JNZ falha
        LDA #0
        LDA $8000,X
        CMP #$77
        JNZ falha
        LDX #$FFFF
        INX
        JNZ falha
        DEX
        JZ falha
        CPX #$FFFF
        JNZ falha
        CPX #$1234
        JC falha
        LDA #$12
        TAXH
        LDA #$34
        TAXL
        CPX #$1234
        JNZ falha
        CPX #$1235
        JNC falha
        TXHA
        CMP #$12
        JNZ falha
        TXLA
        CMP #$34
        JNZ falha
        LDX #1
        DEX
        JNZ falha

        LDA #$AB                ; pilha
        PUSH
        LDA #0
        POP
        CMP #$AB
        JNZ falha
        LDX #$BEEF
        PHX
        LDX #0
        PLX
        CPX #$BEEF
        JNZ falha
        CALL sub
        CMP #$99
        JNZ falha

        LDX #pula               ; JPX
        JPX
        JMP falha
pula:   LDA dado                ; leitura da ROM
        CMP #$C3
        JNZ falha
        NOP
        IN $01                  ; serial parada: status 0
        JNZ falha

        LDA #$55
        OUT RES
        HLT
falha:  LDA #$EE
        OUT RES
        HLT

sub:    LDA #$99
        RET
dado:   DB $C3
