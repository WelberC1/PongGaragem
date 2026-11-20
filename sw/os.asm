; SO provisório: só anuncia e devolve pela serial tudo o que recebe (eco).
; Montado para 8000h; o bootloader o copia da ROM (0100h) para a RAM.
; Será substituído pelo monitor e pelas chamadas de sistema.

        ORG $8000
        LDX #msg
        CALL puts
eco:    CALL getc
        CALL putc
        JMP eco

getc:   IN $01
        AND #1
        JZ getc
        IN $02
        RET

putc:   PUSH
putc1:  IN $01
        AND #2
        JNZ putc1
        POP
        OUT $02
        RET

puts:   LDA 0,X
        JZ puts1
        CALL putc
        INX
        JMP puts
puts1:  RET

msg:    DB "SO GAR-8 v0 (eco)",13,10,0
