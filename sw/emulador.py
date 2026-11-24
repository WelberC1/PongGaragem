"""Emulador da GAR-8 com a tela do Pong, para testar sem a placa.

    python sw/emulador.py sw/teste_video.asm     monta e roda (aceita .asm ou .bin)
    python sw/emulador.py build/teste_video.bin
    python sw/emulador.py --teste                confere o emulador com o teste_cpu.asm

O programa roda a partir de 8000h, como se o bootloader o tivesse carregado.
Teclas: W/S = jogador 1, setas = jogador 2, espaço = S2, Esc = sair.
A serial que o programa envia aparece no terminal; o que se digita no terminal não chega a ele.
A tela imita o rtl/gar8_video.v; a CPU imita o rtl/gar8_cpu.v (ISA em docs/isa.md).
"""
import os
import sys
import threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gasm  # noqa: E402

CPU_HZ = 3_000_000
POR_QUADRO = CPU_HZ // 60          # estados de CPU por quadro
POR_TICK = CPU_HZ // 100           # porta 03h: +1 a cada 10 ms


class GAR8:
    def __init__(self, rom=b'', ram=b'', pc=0):
        self.rom = bytearray(rom.ljust(0x800, b'\0'))
        self.ram = bytearray(0x4000)
        self.ram[:len(ram)] = ram
        self.a, self.x, self.sp, self.pc = 0, 0, 0xC000, pc
        self.z = self.c = False
        self.parada = None                  # motivo, quando a CPU para
        self.ciclos = 0
        self.portas = {0x80: 79, 0x81: 59, 0x82: 52, 0x83: 52, 0x84: 0, 0x85: 0, 0x86: 0xFF, 0x88: 10}
        self.botoes = 0
        self.leds = 0
        self.quadro_novo = False
        self.esperando_quadro = False
        self.ao_escrever = {}               # porta -> função(valor), para serial e som

    # ---------- memória: A15 = 0 ROM, A15 = 1 RAM ----------
    def le(self, e):
        e &= 0xFFFF
        return self.ram[e & 0x3FFF] if e & 0x8000 else self.rom[e & 0x7FF]

    def grava(self, e, v):
        if e & 0x8000:
            self.ram[e & 0x3FFF] = v & 0xFF

    def empilha(self, v):
        self.sp = (self.sp - 1) & 0xFFFF
        self.grava(self.sp, v)

    def desempilha(self):
        v = self.le(self.sp)
        self.sp = (self.sp + 1) & 0xFFFF
        return v

    # ---------- E/S ----------
    def entrada(self, p):
        if p == 0x00:
            return self.botoes
        if p == 0x03:
            return (self.ciclos // POR_TICK) & 0xFF
        if p == 0x87:
            v = int(self.quadro_novo)
            self.quadro_novo = False
            self.esperando_quadro = not v
            return v
        return 0                             # serial: nada chegou, transmissor livre

    def saida(self, p, v):
        if p == 0x03:
            self.leds = v & 0x3F
        elif 0x80 <= p <= 0x88:
            self.portas[p] = v
        if p in self.ao_escrever:
            self.ao_escrever[p](v)

    # ---------- uma instrução ----------
    def passo(self):
        op = self.le(self.pc)
        b1, b2 = self.le(self.pc + 1), self.le(self.pc + 2)
        nn = b1 | b2 << 8
        tam = 1 if op in (0x00, 0x01, 0x2C, 0x2D, 0x31, 0x32, 0x34, 0x35, 0x36, 0x37, 0x45, 0x47, 0x48, 0x49, 0x4A, 0x4B) \
            else 2 if op in (0x10, 0x50, 0x51) or (0x20 <= op <= 0x2B and op % 2 == 0) else 3
        self.pc = (self.pc + tam) & 0xFFFF
        self.ciclos += 2 + tam
        a = self.a

        def flag_z(v):
            self.z = (v & 0xFF) == 0
            return v & 0xFF

        if op == 0x00:
            pass
        elif op == 0x10:
            self.a = flag_z(b1)
        elif op in (0x11, 0x12):
            self.a = flag_z(self.le(nn + (self.x if op == 0x12 else 0)))
            self.ciclos += 1
        elif op in (0x13, 0x14):
            self.grava((nn + (self.x if op == 0x14 else 0)) & 0xFFFF, a)
        elif 0x20 <= op <= 0x2B:
            m = b1 if op % 2 == 0 else self.le(nn)
            k = (op - 0x20) // 2
            if k == 0:
                self.c = a + m > 0xFF
                self.a = flag_z(a + m)
            elif k in (1, 5):
                self.c = a < m
                r = flag_z(a - m)
                if k == 1:
                    self.a = r
            else:
                self.a = flag_z((a & m, a | m, a ^ m)[k - 2])
        elif op == 0x2C:
            self.c = bool(a & 0x80)
            self.a = flag_z(a << 1)
        elif op == 0x2D:
            self.c = bool(a & 1)
            self.a = flag_z(a >> 1)
        elif op == 0x30:
            self.x = nn
        elif op in (0x31, 0x32):
            self.x = (self.x + (1 if op == 0x31 else -1)) & 0xFFFF
            self.z = self.x == 0
        elif op == 0x33:
            self.z, self.c = self.x == nn, self.x < nn
        elif op == 0x34:
            self.x = (self.x & 0xFF00) | a
        elif op == 0x35:
            self.x = (self.x & 0x00FF) | a << 8
        elif op == 0x36:
            self.a = flag_z(self.x)
        elif op == 0x37:
            self.a = flag_z(self.x >> 8)
        elif op == 0x40 or (op == 0x41 and self.z) or (op == 0x42 and not self.z) \
                or (op == 0x43 and self.c) or (op == 0x44 and not self.c):
            self.pc = nn
        elif 0x41 <= op <= 0x44:
            pass
        elif op == 0x45:
            self.pc = self.x
        elif op in (0x46, 0x4A):            # CALL / PHX: byte alto primeiro
            v = self.pc if op == 0x46 else self.x
            self.empilha(v >> 8)
            self.empilha(v & 0xFF)
            self.ciclos += 1
            if op == 0x46:
                self.pc = nn
        elif op in (0x47, 0x4B):            # RET / PLX
            lo = self.desempilha()
            v = lo | self.desempilha() << 8
            self.ciclos += 2
            if op == 0x47:
                self.pc = v
            else:
                self.x = v
        elif op == 0x48:
            self.empilha(a)
        elif op == 0x49:
            self.a = flag_z(self.desempilha())
        elif op == 0x4C:
            self.sp = nn
        elif op == 0x50:
            self.a = flag_z(self.entrada(b1))
        elif op == 0x51:
            self.saida(b1, a)
        else:
            self.parada = 'HLT' if op == 0x01 else f'opcode inválido {op:02X}h'
            self.pc = (self.pc - tam) & 0xFFFF

    def roda_quadro(self):
        """Roda até o fim do quadro atual; se o programa fica esperando a porta 87h, pula o tempo."""
        alvo = (self.ciclos // POR_QUADRO + 1) * POR_QUADRO
        while self.ciclos < alvo and not self.parada:
            self.passo()
            if self.esperando_quadro:
                self.esperando_quadro = False
                self.ciclos = alvo
        self.quadro_novo = True


def autoteste():
    """Roda sw/teste_cpu.asm (o mesmo do tb_cpu.v) e espera 55h na porta F0h."""
    raiz = os.path.dirname(os.path.abspath(__file__))
    org, img = gasm.assemble_file(os.path.join(raiz, 'teste_cpu.asm'))
    cpu = GAR8(rom=img)
    res = []
    cpu.ao_escrever[0xF0] = res.append
    while not res and not cpu.parada and cpu.ciclos < 1_000_000:
        cpu.passo()
    assert res == [0x55], f'emulador: teste da CPU falhou (pc={cpu.pc:04X}h, {cpu.parada}, {res})'
    print('OK: emulador passou no teste da CPU')


# ---------- tela (imita o rtl/gar8_video.v) ----------
FONTE = ['111101101101111', '010110010010111', '111001111100111', '111001111001111', '101101111001001',
         '111100111001111', '111100111101111', '111001001001001', '111101111101111', '111101111001111']
CASA = 4
LEDS_Y = 480


def cor_hex(c):
    r, g, b = (c >> 5) * 255 // 7, (c >> 2 & 7) * 255 // 7, (c & 3) * 255 // 3
    return f'#{r:02x}{g:02x}{b:02x}'


def desenha(tela, cpu):
    tela.delete('jogo')
    p = cpu.portas
    cor = cor_hex(p[0x86])

    def ret(cx, cy, w, h):
        tela.create_rectangle(cx * CASA, cy * CASA, (cx + w) * CASA, (cy + h) * CASA, fill=cor, width=0, tags='jogo')

    ret(p[0x80], p[0x81], 2, 2)
    ret(4, p[0x82], 2, 16)
    ret(154, p[0x83], 2, 16)
    for cy in range(0, 120, 4):
        ret(79, cy, 1, 2)
    for x0, v in ((58, p[0x84]), (88, p[0x85])):
        v = min(v, 99)
        for i, d in enumerate((v // 10, v % 10)):
            if i == 0 and d == 0:
                continue
            for k, bit in enumerate(FONTE[d]):
                if bit == '1':
                    ret(x0 + 8 * i + (k % 3) * 2, 4 + (k // 3) * 2, 2, 2)
    for i in range(6):
        tela.create_oval(16 + i * 28, LEDS_Y + 10, 32 + i * 28, LEDS_Y + 26, tags='jogo',
                         fill='#ffcc00' if cpu.leds >> i & 1 else '#333333', width=0)


def janela(cpu):
    import tkinter as tk
    raiz = tk.Tk()
    raiz.title('GAR-8 — emulador')
    raiz.resizable(False, False)
    tela = tk.Canvas(raiz, width=640, height=LEDS_Y + 36, bg='black', highlightthickness=0)
    tela.pack()
    tela.create_rectangle(0, LEDS_Y, 640, LEDS_Y + 36, fill='#181818', width=0)
    tela.create_text(630, LEDS_Y + 18, anchor='e', fill='#999999', font=('Segoe UI', 9),
                     text='LEDs 0–5   |   W/S jogador 1   ↑/↓ jogador 2   espaço S2   Esc sai')

    teclas = {'space': 1, 'w': 2, 's': 4, 'Up': 8, 'Down': 16}
    apertadas = set()
    raiz.bind('<KeyPress>', lambda e: apertadas.add(e.keysym.lower() if len(e.keysym) == 1 else e.keysym))
    raiz.bind('<KeyRelease>', lambda e: apertadas.discard(e.keysym.lower() if len(e.keysym) == 1 else e.keysym))
    raiz.bind('<Escape>', lambda e: raiz.destroy())

    def quadro():
        cpu.botoes = sum(bit for nome, bit in teclas.items() if nome in apertadas)
        cpu.roda_quadro()
        desenha(tela, cpu)
        if cpu.parada:
            raiz.title(f'GAR-8 — parou em {cpu.pc:04X}h: {cpu.parada}')
        else:
            raiz.after(16, quadro)
    quadro()
    raiz.mainloop()


def som(cpu):
    try:
        import winsound
    except ImportError:
        return

    def toca(n):
        if n:
            ms = cpu.portas[0x88] * 10
            threading.Thread(target=winsound.Beep, args=(max(37, 23437 // n), max(ms, 1)), daemon=True).start()
    cpu.ao_escrever[0x8A] = toca


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    if sys.argv[1] == '--teste':
        autoteste()
        return
    arq = sys.argv[1]
    if arq.lower().endswith('.asm'):
        org, img = gasm.assemble_file(arq)
        if org != 0x8000:
            sys.exit(f'{arq}: precisa de ORG $8000 (começa em {org:04X}h)')
    else:
        with open(arq, 'rb') as f:
            img = f.read()
    cpu = GAR8(ram=img, pc=0x8000)
    cpu.ao_escrever[0x02] = lambda v: print(chr(v), end='', flush=True)
    som(cpu)
    janela(cpu)


if __name__ == '__main__':
    main()
