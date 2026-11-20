; Programa pequeno para testar a carga pela serial: imprime "NOVO" e para.
        ORG $8000
        LDX #m
l:      LDA 0,X
        JZ f
        PUSH
w:      IN $01
        AND #2
        JNZ w
        POP
        OUT $02
        INX
        JMP l
f:      HLT
m:      DB "NOVO",13,10,0
