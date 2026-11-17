#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario_sequencial="$raiz_projeto/bin/sequencial"
binario_paralelo="$raiz_projeto/bin/paralelo"
diretorio_temporario="$(mktemp -d)"

trap 'rm -rf "$diretorio_temporario"' EXIT

for binario in "$binario_sequencial" "$binario_paralelo"; do
    if [[ ! -x "$binario" ]]; then
        printf 'Executável não encontrado em %s.\n' "$binario" >&2
        exit 1
    fi
done

criar_entrada()
{
    local nome="$1"
    shift

    printf '%s\n' "$@" > "$diretorio_temporario/$nome.txt"
}

esperar_falha()
{
    local descricao="$1"
    local mensagem_esperada="$2"
    shift 2

    if "$@" > /dev/null 2> "$diretorio_temporario/erro.txt"; then
        printf 'Era esperada uma falha em: %s.\n' "$descricao" >&2
        exit 1
    fi

    if ! grep -Fq "$mensagem_esperada" "$diretorio_temporario/erro.txt"; then
        printf 'Mensagem de erro inesperada em: %s.\n' "$descricao" >&2
        sed 's/^/  /' "$diretorio_temporario/erro.txt" >&2
        exit 1
    fi

    ((validacoes += 1))
    printf 'Falha esperada confirmada | %s\n' "$descricao"
}

criar_entrada geracoes-negativas \
    '-1' \
    '1 1' \
    '0'
criar_entrada dimensao-zero \
    '1' \
    '0 2' \
    '0'
criar_entrada vivas-excedem-matriz \
    '1' \
    '2 2' \
    '5'
criar_entrada coordenada-fora-limites \
    '1' \
    '2 2' \
    '1' \
    '2 0'
criar_entrada coordenada-repetida \
    '1' \
    '2 2' \
    '2' \
    '0 0' \
    '0 0'
criar_entrada arquivo-incompleto \
    '1' \
    '2 2' \
    '2' \
    '0 0'
criar_entrada valida-2x2 \
    '1' \
    '2 2' \
    '1' \
    '0 0'

entradas_invalidas=(
    geracoes-negativas
    dimensao-zero
    vivas-excedem-matriz
    coordenada-fora-limites
    coordenada-repetida
    arquivo-incompleto
)
validacoes=0

for nome in "${entradas_invalidas[@]}"; do
    entrada="$diretorio_temporario/$nome.txt"
    esperar_falha "$nome na versão sequencial" \
        'Arquivo de entrada invalido.' \
        "$binario_sequencial" "$entrada"
    esperar_falha "$nome na versão Pthreads" \
        'Arquivo de entrada invalido.' \
        "$binario_paralelo" "$entrada" 1
done

entrada_valida="$diretorio_temporario/valida-2x2.txt"
esperar_falha 'zero threads' \
    'Quantidade de threads invalida.' \
    "$binario_paralelo" "$entrada_valida" 0
esperar_falha 'quantidade de threads não numérica' \
    'Quantidade de threads invalida.' \
    "$binario_paralelo" "$entrada_valida" texto
esperar_falha 'mais threads que linhas' \
    'A quantidade de threads nao pode exceder a quantidade de linhas.' \
    "$binario_paralelo" "$entrada_valida" 3

printf 'Validação de erros concluída: %d falhas esperadas.\n' \
    "$validacoes"
