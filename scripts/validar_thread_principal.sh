#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario_sequencial="$raiz_projeto/bin/sequencial"
binario_paralelo="$raiz_projeto/bin/paralelo"
diretorio_temporario="$(mktemp -d)"
diretorio_entradas="$diretorio_temporario/entradas"
timeout_segundos="${TIMEOUT_VALIDACAO_SEGUNDOS:-10}"
timeout_memoria_segundos="${TIMEOUT_MEMORIA_SEGUNDOS:-30}"
validar_memoria="${VALIDAR_MEMORIA:-0}"

trap 'rm -rf "$diretorio_temporario"' EXIT

validar_inteiro_positivo()
{
    local nome="$1"
    local valor="$2"

    if [[ ! "$valor" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s deve ser um inteiro maior que zero.\n' "$nome" >&2
        exit 1
    fi
}

criar_entrada()
{
    local nome="$1"
    shift

    printf '%s\n' "$@" > "$diretorio_entradas/$nome.txt"
}

executar_com_timeout()
{
    local descricao="$1"
    local limite_segundos="$2"
    local status
    shift 2

    if timeout "${limite_segundos}s" "$@"; then
        return 0
    else
        status=$?
    fi

    if ((status == 124)); then
        printf 'Tempo limite excedido em %s após %d segundo(s).\n' \
            "$descricao" \
            "$limite_segundos" \
            >&2
    else
        printf 'Falha em %s com status %d.\n' "$descricao" "$status" >&2
    fi

    return "$status"
}

validar_inteiro_positivo TIMEOUT_VALIDACAO_SEGUNDOS "$timeout_segundos"
validar_inteiro_positivo TIMEOUT_MEMORIA_SEGUNDOS "$timeout_memoria_segundos"

if [[ "$validar_memoria" != "0" && "$validar_memoria" != "1" ]]; then
    printf 'VALIDAR_MEMORIA deve ser 0 ou 1.\n' >&2
    exit 1
fi

for binario in "$binario_sequencial" "$binario_paralelo"; do
    if [[ ! -x "$binario" ]]; then
        printf 'Executável não encontrado em %s.\n' "$binario" >&2
        exit 1
    fi
done

if [[ "$validar_memoria" == "1" ]] && ! command -v valgrind > /dev/null; then
    printf 'Valgrind não está disponível para a validação de memória.\n' >&2
    exit 1
fi

mkdir -p "$diretorio_entradas"

criar_entrada tres-geracoes-7x9 \
    '3' \
    '7 9' \
    '5' \
    '1 2' \
    '2 3' \
    '3 1' \
    '3 2' \
    '3 3'

criar_entrada quatro-geracoes-8x7 \
    '4' \
    '8 7' \
    '6' \
    '1 1' \
    '1 2' \
    '2 1' \
    '5 4' \
    '6 4' \
    '6 5'

entradas=(
    "$diretorio_entradas/tres-geracoes-7x9.txt"
    "$diretorio_entradas/quatro-geracoes-8x7.txt"
)
quantidades_threads=(1 2 4)
comparacoes=0

for indice in "${!entradas[@]}"; do
    entrada="${entradas[$indice]}"
    nome_entrada="$(basename "$entrada")"
    saida_sequencial="$diretorio_temporario/sequencial-$indice.txt"

    executar_com_timeout \
        "sequencial de $nome_entrada" \
        "$timeout_segundos" \
        "$binario_sequencial" \
        "$entrada" \
        > "$saida_sequencial"

    for quantidade_threads in "${quantidades_threads[@]}"; do
        saida_paralela="$diretorio_temporario/paralelo-$indice-$quantidade_threads.txt"

        executar_com_timeout \
            "Pthreads de $nome_entrada com $quantidade_threads participante(s)" \
            "$timeout_segundos" \
            "$binario_paralelo" \
            "$entrada" \
            "$quantidade_threads" \
            > "$saida_paralela"

        if ! cmp -s "$saida_sequencial" "$saida_paralela"; then
            printf 'Saída divergente em %s com %d participante(s).\n' \
                "$nome_entrada" \
                "$quantidade_threads" \
                >&2
            diff -u "$saida_sequencial" "$saida_paralela" \
                | sed -n '1,120p' \
                >&2
            exit 1
        fi

        ((comparacoes += 1))
        printf 'Saída idêntica | Entrada=%s | Participantes=%d\n' \
            "$nome_entrada" \
            "$quantidade_threads"
    done
done

printf 'Validação reduzida concluída: %d comparações idênticas.\n' \
    "$comparacoes"

if [[ "$validar_memoria" == "1" ]]; then
    entrada_memoria="${entradas[0]}"
    nome_entrada_memoria="$(basename "$entrada_memoria")"
    verificacoes_memoria=0

    for quantidade_threads in "${quantidades_threads[@]}"; do
        arquivo_valgrind="$diretorio_temporario/valgrind-$quantidade_threads.txt"

        if ! executar_com_timeout \
            "Valgrind de $nome_entrada_memoria com $quantidade_threads participante(s)" \
            "$timeout_memoria_segundos" \
            valgrind \
            --leak-check=full \
            --show-leak-kinds=all \
            --errors-for-leak-kinds=all \
            --error-exitcode=97 \
            "$binario_paralelo" \
            "$entrada_memoria" \
            "$quantidade_threads" \
            > /dev/null \
            2> "$arquivo_valgrind"; then
            sed -n '1,160p' "$arquivo_valgrind" >&2
            exit 1
        fi

        ((verificacoes_memoria += 1))
        printf 'Memória validada | Entrada=%s | Participantes=%d\n' \
            "$nome_entrada_memoria" \
            "$quantidade_threads"
    done

    printf 'Validação de memória concluída: %d configuração(ões).\n' \
        "$verificacoes_memoria"
fi
