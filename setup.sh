#!/usr/bin/env bash
# Adds the bin folder to the PATH on Linux, macOS and Git Bash. Safe to run more than once.
set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$REPO_DIR/bin"

chmod +x "$BIN_DIR/bf"

if ! command -v node >/dev/null 2>&1; then
    echo "Aviso: Node.js não encontrado. O comando bf precisa dele: https://nodejs.org" >&2
fi

# Escapes the characters that stay special inside double quotes.
ESCAPED_BIN_DIR="$(printf '%s' "$BIN_DIR" | sed 's/[\\"$`]/\\&/g')"
PATH_LINE="export PATH=\"\$PATH:$ESCAPED_BIN_DIR\""

SHELL_NAME="$(basename -- "${SHELL:-sh}")"
case "$SHELL_NAME" in
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    bash)
        if [ "$(uname -s)" = "Darwin" ]; then
            RC_FILE="$HOME/.bash_profile"
        else
            RC_FILE="$HOME/.bashrc"
        fi
        ;;
    sh | dash | ksh)
        RC_FILE="$HOME/.profile"
        ;;
    *)
        echo "Shell não reconhecido ($SHELL_NAME). Adicione esta pasta ao PATH manualmente:"
        echo "  $BIN_DIR"
        exit 0
        ;;
esac

if [ -f "$RC_FILE" ] && grep -Fxq -- "$PATH_LINE" "$RC_FILE"; then
    echo "$RC_FILE já adiciona $BIN_DIR ao PATH"
else
    printf '\n# bf (Brainfuck CLI)\n%s\n' "$PATH_LINE" >> "$RC_FILE"
    echo "Adicionado ao PATH em $RC_FILE: $BIN_DIR"
fi

echo "Pronto. Abra um terminal novo e teste: bf '++++++++[>++++++++<-]>+.'"
