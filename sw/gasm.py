"""Montador da GAR-8 (ISA em docs/isa.md).

Uso: python gasm.py programa.asm saida.bin

Sintaxe:
    rotulo:  MNEMONICO operando   ; comentário
    NOME EQU valor
    ORG endereço | DB 1,"texto",'c' | DW palavra | DS quantidade
Números: 255, $FF, 0xFF, %1010, 'A'. Expressões: + e -, <x (byte baixo), >x (byte alto).
Operandos: #n (imediato), end, end,X, porta (IN/OUT).
"""
import re
import sys

OPS = {
    ('NOP', ''): 0x00, ('HLT', ''): 0x01,
    ('LDA', '#'): 0x10, ('LDA', 'a'): 0x11, ('LDA', 'ax'): 0x12,
    ('STA', 'a'): 0x13, ('STA', 'ax'): 0x14,
    ('ADD', '#'): 0x20, ('ADD', 'a'): 0x21, ('SUB', '#'): 0x22, ('SUB', 'a'): 0x23,
    ('AND', '#'): 0x24, ('AND', 'a'): 0x25, ('OR', '#'): 0x26, ('OR', 'a'): 0x27,
    ('XOR', '#'): 0x28, ('XOR', 'a'): 0x29, ('CMP', '#'): 0x2A, ('CMP', 'a'): 0x2B,
    ('SHL', ''): 0x2C, ('SHR', ''): 0x2D,
    ('LDX', '#16'): 0x30, ('INX', ''): 0x31, ('DEX', ''): 0x32, ('CPX', '#16'): 0x33,
    ('TAXL', ''): 0x34, ('TAXH', ''): 0x35, ('TXLA', ''): 0x36, ('TXHA', ''): 0x37,
    ('JMP', 'a'): 0x40, ('JZ', 'a'): 0x41, ('JNZ', 'a'): 0x42, ('JC', 'a'): 0x43,
    ('JNC', 'a'): 0x44, ('JPX', ''): 0x45, ('CALL', 'a'): 0x46, ('RET', ''): 0x47,
    ('PUSH', ''): 0x48, ('POP', ''): 0x49, ('PHX', ''): 0x4A, ('PLX', ''): 0x4B,
    ('LDSP', '#16'): 0x4C, ('IN', 'p'): 0x50, ('OUT', 'p'): 0x51,
}
SIZE = {'': 1, '#': 2, 'p': 2, '#16': 3, 'a': 3, 'ax': 3}
MNEMS = {m for m, _ in OPS}


class AsmError(Exception):
    pass


def split_outside_quotes(s, sep):
    parts, cur, q = [], '', None
    for ch in s:
        if q:
            cur += ch
            if ch == q:
                q = None
        elif ch in '"\'':
            q = ch
            cur += ch
        elif ch == sep:
            parts.append(cur)
            cur = ''
        else:
            cur += ch
    parts.append(cur)
    return parts


def number(tok):
    if re.fullmatch(r"'.'", tok):
        return ord(tok[1])
    for pre, base in (('$', 16), ('0x', 16), ('0X', 16), ('%', 2)):
        if tok.startswith(pre):
            return int(tok[len(pre):], base)
    if tok.isdigit():
        return int(tok)
    return None


def ev(expr, syms, final):
    expr = expr.strip()
    if not expr:
        raise AsmError('expressão vazia')
    if expr[0] in '<>':
        v = ev(expr[1:], syms, final)
        return v & 0xFF if expr[0] == '<' else (v >> 8) & 0xFF
    if re.fullmatch(r"'.'", expr):
        return ord(expr[1])
    total, sign = 0, 1
    for tok in re.split(r'([+-])', expr):
        tok = tok.strip()
        if tok in ('+', '-'):
            sign = 1 if tok == '+' else -1
            continue
        if not tok:
            continue
        v = number(tok)
        if v is None:
            if tok.upper() in syms:
                v = syms[tok.upper()]
            elif final:
                raise AsmError(f'símbolo indefinido: {tok}')
            else:
                v = 0
        total += sign * v
    return total


def check(v, lo, hi, what):
    if not lo <= v <= hi:
        raise AsmError(f'{what} fora da faixa: {v}')
    return v


def assemble(src):
    syms, out = {}, {}
    for final in (False, True):
        pc = 0
        for n, raw in enumerate(src.splitlines(), 1):
            try:
                line = split_outside_quotes(raw, ';')[0].rstrip()
                m = re.match(r'^\s*(\w+):', line)
                if m:
                    name = m.group(1).upper()
                    if not final and name in syms:
                        raise AsmError(f'rótulo repetido: {name}')
                    syms[name] = pc
                    line = line[m.end():]
                parts = line.split(None, 1)
                if not parts:
                    continue
                if len(parts) == 2 and parts[1].split(None, 1)[0].upper() in ('EQU', '='):
                    syms[parts[0].upper()] = ev(parts[1].split(None, 1)[1], syms, final)
                    continue
                mn = parts[0].upper()
                arg = parts[1].strip() if len(parts) > 1 else ''
                if mn == 'ORG':
                    pc = check(ev(arg, syms, True), 0, 0xFFFF, 'ORG')
                    continue
                if mn in ('DB', 'DW', 'DS'):
                    data = []
                    if mn == 'DS':
                        data = [0] * ev(arg, syms, True)
                    for item in (split_outside_quotes(arg, ',') if mn != 'DS' else []):
                        item = item.strip()
                        if mn == 'DB' and len(item) >= 2 and item[0] == item[-1] == '"':
                            data += item[1:-1].encode('latin-1')
                        elif mn == 'DB':
                            data.append(check(ev(item, syms, final), -128, 255, 'byte') & 0xFF)
                        else:
                            v = check(ev(item, syms, final), 0, 0xFFFF, 'palavra')
                            data += [v & 0xFF, v >> 8]
                    for b in data:
                        out[pc] = b
                        pc += 1
                    continue
                if mn not in MNEMS:
                    raise AsmError(f'instrução desconhecida: {mn}')
                if mn in ('IN', 'OUT'):
                    mode = 'p'
                elif not arg:
                    mode = ''
                elif arg.startswith('#'):
                    mode = '#16' if (mn, '#16') in OPS else '#'
                    arg = arg[1:]
                elif re.search(r',\s*[xX]$', arg):
                    mode, arg = 'ax', re.sub(r',\s*[xX]$', '', arg)
                else:
                    mode = 'a'
                if (mn, mode) not in OPS:
                    raise AsmError(f'{mn} não aceita esse operando')
                code = [OPS[(mn, mode)]]
                if mode:
                    v = ev(arg, syms, final)
                    if mode in ('#', 'p'):
                        code.append(check(v, -128, 255, 'valor de 8 bits') & 0xFF)
                    else:
                        v = check(v, 0, 0xFFFF, 'valor de 16 bits')
                        code += [v & 0xFF, v >> 8]
                for b in code:
                    out[pc] = b
                    pc += 1
            except AsmError as e:
                raise AsmError(f'linha {n}: {e}\n    {raw.strip()}') from None
    return out, syms


def to_bytes(out):
    """Imagem contínua do menor ao maior endereço usado: (origem, bytes)."""
    if not out:
        return 0, b''
    lo, hi = min(out), max(out)
    return lo, bytes(out.get(a, 0) for a in range(lo, hi + 1))


def assemble_file(path):
    with open(path, encoding='utf-8') as f:
        return to_bytes(assemble(f.read())[0])


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    try:
        org, img = assemble_file(sys.argv[1])
    except AsmError as e:
        sys.exit(f'{sys.argv[1]}: {e}')
    with open(sys.argv[2], 'wb') as f:
        f.write(img)
    print(f'{sys.argv[2]}: {len(img)} bytes a partir de {org:04X}h')
