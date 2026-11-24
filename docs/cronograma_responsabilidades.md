# Pong-Garagem — cronograma e responsabilidades do grupo

> Documento de contexto. Atualizado em **24/11/2026**.

## 1. Contexto do projeto

- **Curso:** Pós-graduação em Computação Aplicada, IFSP campus Guarulhos (Projeto Garagem).
- **Grupo:** Welber Caetano Santos, Mariana Bastos Esteves, Lilian Letícia Firino Zilmar.
- **Objetivo:** construir um computador de 8 bits com CPU própria (**GAR-8**) dentro de uma FPGA e rodar nele um **Pong** para dois jogadores, com vídeo HDMI, som e botões de fliperama.
- **Placa:** Sipeed Tang Nano 20K (FPGA Gowin GW2AR-18, clock de 27 MHz). A placa **já chegou**, antes da data prevista de 25/11, e desde 24/11 **está com a Lilian**, que faz os testes no hardware.
- **Ferramentas:** OSS CAD Suite (Yosys, nextpnr-himbaechel, Icarus Verilog, GTKWave, openFPGALoader), Python 3 com pyserial, KiCad 10 e PuTTY.
- **Repositório local:** `C:\Github\pong-garagem`
  - `docs/isa.md`: lista de instruções, mapa de memória e portas de E/S
  - `docs/Guia_Pong-Garagem.pdf`: guia completo do projeto
  - `rtl/`: Verilog (CPU, SoC e topo da placa)
  - `sw/`: montador `gasm.py`, `boot.asm`, `os.asm` e `carregar.py`
  - `tb/`: testes de simulação
  - `build.py`: comandos `sim` (testa), `placa` (gera o bitstream) e `gravar` (grava na placa)

### Arquitetura em resumo

- **CPU GAR-8:** 8 bits, com acumulador, endereços de 16 bits e 45 instruções. Registradores A, X (16 bits), SP e PC; flags Z e C. Roda a 3 MHz.
- **Memória:** ROM de 2 KB (0000h–07FFh: bootloader + imagem do SO) e RAM de 16 KB (8000h–BFFFh: SO, programa e pilha).
- **E/S 0 (portas 00h–03h):** botões, serial (9600 bps), LEDs e contador de tempo (10 ms).
- **E/S 1 (portas 80h–8Ah):** vídeo (posições, placar, cor, aviso de quadro novo) e som (nota e duração).
- **Bootloader:** pisca os LEDs, copia o SO da ROM para a RAM e espera 2 s pelo comando `S` na serial. Se receber, carrega um programa novo com soma de verificação. Depois pula para 8000h.

## 2. Situação atual (24/11)

| Item | Estado |
|---|---|
| Placa gravando e driver instalado | ✅ feito |
| ISA definida (`docs/isa.md`) | ✅ aprovada pelo grupo |
| CPU + SoC (ROM, RAM, serial, LEDs, tempo) | ✅ testado em simulação e na placa |
| Montador em Python | ✅ feito |
| Bootloader | ✅ testado em simulação e na placa |
| Carregador serial do PC | ✅ testado na placa |
| SO de verdade (monitor + chamadas de sistema) | ⬜ próximo passo |
| Vídeo HDMI | 🟨 pronto e testado em simulação (`build/quadro.png`); falta testar na placa |
| Som (I2S, amplificador MAX98357A da placa) | 🟨 pronto e testado em simulação; falta testar na placa |
| Botões de fliperama | 🟨 lógica e pinos prontos; falta montar na protoboard |
| Jogo Pong | ⬜ |
| Placa de expansão (KiCad) | ❌ não será feita: decidimos usar **protoboard** |

## 3. Responsabilidades

Cada frente tem um **responsável**, que garante a entrega, e um **apoio**, que revisa e cobre se o responsável travar.

### 🔧 Welber: hardware na FPGA e integração
Faz o Verilog e testa em simulação; a Lilian grava na placa e devolve o resultado.
- Vídeo HDMI: PLL, varredura 640×480 a 60 Hz, codificador TMDS e o circuito que desenha bola, raquetes e placar.
- Som: gerador de tom e transmissor I2S para o amplificador da placa.
- Portas de E/S 1 (80h–8Ah) no SoC.
- Corrigir o que aparecer nos testes da placa e, com a Lilian, gravar a versão final na flash.
- **Apoio de:** Mariana (revisão do Verilog, testes em simulação).

### 💻 Mariana: software em Assembly da GAR-8
Dá para trabalhar só no simulador, sem a placa (`python build.py sim`).
- SO: monitor serial (comandos M, W, L, G, ?) e tabela de chamadas de sistema em 8003h–8012h.
- Jogo Pong: laço de 60 quadros por segundo, colisões, placar, aceleração da bola e modo demonstração após 10 s sem ninguém jogar.
- Testes de simulação do SO (`tb/tb_os.v`).
- **Apoio de:** Welber (dúvidas da CPU e da ISA).

### 🛠️ Lilian: placa, protoboard, testes e documentação
- Fica com a placa: grava cada versão e segue o `docs/roteiro_placa.md`.
- Botões de fliperama na protoboard (ligação no roteiro; não precisa de resistor).
- Compras: 4 botões, alto-falante de 8 Ω, protoboard, fios jumper e cabo HDMI.
- Registro dos resultados no roteiro e no Git.
- Artigo final (base: `docs/isa.md` e o guia em PDF) e roteiro da apresentação na Mostra.
- **Apoio de:** Mariana (artigo), Welber (pinos da placa).

### 👥 Tarefas de todos
- Aprovar a ISA (`docs/isa.md`) **antes de 21/11**.
- Checkpoint em 10/12 e ensaio da Mostra.

## 4. Cronograma

| Data | Entrega | Responsável | Pronto quando |
|---|---|---|---|
| 20/11 | ✅ CPU, montador, bootloader na placa | Welber | Já concluído |
| ✅ 21/11 | Aprovação da ISA | Todos | Aprovada |
| ✅ 24/11 | Decisão: protoboard em vez da placa de expansão | Todos | Decidido |
| ✅ 24/11 | Fases 4, 5 e 6 em simulação (vídeo, som, botões) | Welber | `python build.py sim` passa |
| 25/11 → 27/11 | Preparar o notebook, montar os botões e rodar o `roteiro_placa.md` | Lilian | Checklist preenchido |
| 21/11 → 24/11 | **Fase 3: SO** (monitor + chamadas de sistema) | Mariana | Pelo PuTTY: ver memória, gravar byte, carregar e executar programa |
| 21/11 → 26/11 | Compras (botões, alto-falante, protoboard, fios, HDMI) | Lilian | Peças em mãos |
| 25/11 → 30/11 | **Fase 4: vídeo HDMI na placa** (ajustes) | Welber + Lilian | Bola do `teste_video` andando no monitor |
| 25/11 → 30/11 | Rascunho da lógica do Pong (simulação, sem vídeo) | Mariana | Posições corretas da bola nas portas, no simulador |
| 25/11 → 30/11 | **Fases 5 e 6 na placa**: som e botões | Lilian (+ Welber) | Bip no alto-falante; cada botão acende seu LED |
| 04/12 → 09/12 | **Fase 7: Pong completo** | Mariana (+ Welber na placa) | Partida inteira com 2 jogadores + modo demo |
| 04/12 → 09/12 | Artigo: primeira versão | Lilian | Seções de arquitetura e ISA escritas |
| **10/12** | 🚩 **Checkpoint**: bootloader + SO rodando na placa | Todos | (já adiantado) |
| 11/12 → 13/12 | Gravar na flash, ensaio, plano B pronto | Todos | Placa liga direto no jogo |
| **14/12** | 🏁 **Mostra Garagem** | Todos | — |
| **17/12** | 📄 Artigo + repositório Git | Lilian (+ todos revisam) | Entregue |

## 5. Riscos e plano B

| Risco | Plano B |
|---|---|
| Vídeo HDMI atrasa | Jogo no terminal serial (já previsto na proposta) |
| GAR-8 com problema grave | Núcleo Z80 aberto (citado na proposta) |
| Pinos de HDMI ou som errados | Usar só os pinos dos exemplos oficiais da Sipeed (`github.com/sipeed/TangNano-20K-example`) |
| Serial da placa trava | Abrir a COM4 só depois de gravar; se travar, desconectar e reconectar o USB |

## 6. Pendências de decisão do grupo

1. Como a placa vai e volta entre Lilian e Welber (encontros para integrar ou só fotos/vídeos).
2. Quem leva o quê no dia da Mostra (placa, notebook, monitor HDMI, alto-falante, botões).
