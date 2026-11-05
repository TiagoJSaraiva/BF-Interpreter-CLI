# bf: interpretador de Brainfuck para o terminal

`bf` executa programas [Brainfuck](https://pt.wikipedia.org/wiki/Brainfuck) a partir de um arquivo `.bf` ou de código passado direto no terminal.

```powershell
bf examples/hello_world.bf
# Hello World!

bf '++++++++[>++++++++<-]>+.'
# A
```

## Requisitos

- [Node.js](https://nodejs.org). Não há dependências para instalar.
- PowerShell no Windows, ou bash no Linux, no macOS e no Git Bash.

## Instalação

Clone o repositório e rode o setup da sua plataforma. O setup só adiciona a pasta `bin` ao seu PATH e pode ser executado mais de uma vez sem duplicar nada.

**Windows (PowerShell):**

```powershell
.\setup.ps1
```

O PATH alterado é o do seu usuário, então não é preciso ser administrador. Se o Windows bloquear o script, rode:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

Esse comando libera apenas o setup. O `bf` também é um script PowerShell, e o setup avisa se a política da sua máquina for impedi-lo de rodar. Para liberar scripts locais no seu usuário:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**Linux, macOS e Git Bash:**

```bash
bash setup.sh
```

O script acrescenta o PATH ao arquivo de configuração do seu shell:

| Shell | Arquivo |
|---|---|
| zsh | `~/.zshrc` |
| bash no Linux e no Git Bash | `~/.bashrc` |
| bash no macOS | `~/.bash_profile` |
| sh, dash, ksh | `~/.profile` |

Em outros shells, como o fish, ele não altera nada e mostra a pasta para você adicionar manualmente.

Depois do setup, abra um terminal novo. O caminho registrado é absoluto, então **rode o setup de novo se mover o repositório**.

## Uso

```
bf <código | arquivo.bf>
bf -h | --help
```

O argumento é interpretado assim:

| Argumento | O que acontece |
|---|---|
| Termina em `.bf` | Executa o arquivo |
| Só tem comandos Brainfuck e espaços | Executa como código |
| Qualquer outra coisa | Erro; `foo.txt`, por exemplo, é recusado |

**Use sempre aspas simples no código**, porque `<`, `>` e `[` têm significado especial nos shells.

### Entrada

O comando `,` lê um byte da entrada padrão, seja do teclado ou de um pipe:

```powershell
'abc' | bf ',[.,]'      # PowerShell
```

```bash
echo abc | bf ',[.,]'   # bash
```

## A linguagem

| Comando | Efeito |
|---|---|
| `>` | Move o ponteiro uma célula para a direita |
| `<` | Move o ponteiro uma célula para a esquerda |
| `+` | Incrementa a célula atual em 1 |
| `-` | Decrementa a célula atual em 1 |
| `.` | Escreve o byte da célula atual na saída |
| `,` | Lê um byte da entrada para a célula atual |
| `[` | Se a célula atual for 0, pula para depois do `]` correspondente |
| `]` | Se a célula atual não for 0, volta para depois do `[` correspondente |

### Comentários

Em arquivos `.bf`, qualquer caractere fora dos 8 comandos é ignorado. **`#` não inicia um comentário**: o texto é ignorado por não conter comandos, e não por causa do `#`. Um ponto final no meio de uma frase, portanto, é um `.` de verdade e imprime um byte:

```brainfuck
# Isto é ignorado
# Isto imprime a célula atual.
```

## Comportamento

- **Fita:** 30.000 células, todas começando em 0.
- **Células:** 8 bits com volta, ou seja, 255 + 1 = 0 e 0 - 1 = 255.
- **Fim da entrada:** `,` grava 0 na célula.
- **Saída:** os bytes saem exatamente como o programa os emite. Nenhuma quebra de linha é acrescentada, e sequências UTF-8 são preservadas.

### Erros

As mensagens vão para o stderr, com exit code 1:

| Erro | Quando |
|---|---|
| Sintaxe | `[` ou `]` sem par. É detectado antes de executar e informa linha e coluna |
| Execução | O ponteiro sai da fita. O que o programa já tinha escrito é mantido |
| Argumento | Arquivo não encontrado, argumento inválido ou mais de um argumento |

Os exit codes são:

| Código | Significado |
|---|---|
| 0 | Sucesso |
| 1 | Um dos erros acima, ou `bf` sem argumentos |
| 127 | Node.js não encontrado |

## Limitações

- O `cmd.exe` não é suportado. Nele, o `>` do código seria tratado como redirecionamento, então use o PowerShell.
- No console do Windows, caracteres não ASCII digitados para o `,` chegam na codificação do console. Por pipe no PowerShell, chegam em UTF-8.

## Desinstalação

- **Windows:** remova a pasta `bin` em *Configurações > Sistema > Sobre > Configurações avançadas do sistema > Variáveis de Ambiente*, na variável `Path` do usuário.
- **Linux, macOS e Git Bash:** apague as linhas `# bf (Brainfuck CLI)` e `export PATH=...` do arquivo de configuração do shell.

Depois, apague o repositório.

## Estrutura

```
bin/bf                  entrada para bash
bin/bf.ps1              entrada para PowerShell
bf_interpreter.js       o interpretador
setup.ps1, setup.sh     configuração do PATH
examples/               programas de exemplo
```
