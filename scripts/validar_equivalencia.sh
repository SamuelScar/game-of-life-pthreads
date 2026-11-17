#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario_sequencial="$raiz_projeto/bin/sequencial"
binario_paralelo="$raiz_projeto/bin/paralelo"
diretorio_temporario="$(mktemp -d)"
diretorio_casos_gerados="$diretorio_temporario/casos-gerados"
threads_lista="${THREADS_LISTA:-1 2 4 8}"

trap 'rm -rf "$diretorio_temporario"' EXIT

mkdir -p "$diretorio_casos_gerados"

criar_entrada()
{
    local nome="$1"
    shift

    printf '%s\n' "$@" > "$diretorio_casos_gerados/$nome.txt"
}

criar_entrada zero-geracoes-1x1 \
    '0' \
    '1 1' \
    '1' \
    '0 0'
criar_entrada uma-geracao-1x5 \
    '1' \
    '1 5' \
    '3' \
    '0 1' \
    '0 2' \
    '0 3'
criar_entrada duas-geracoes-5x1 \
    '2' \
    '5 1' \
    '3' \
    '1 0' \
    '2 0' \
    '3 0'
criar_entrada tres-geracoes-7x9 \
    '3' \
    '7 9' \
    '5' \
    '1 2' \
    '2 3' \
    '3 1' \
    '3 2' \
    '3 3'
criar_entrada uma-thread-por-linha-8x7 \
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
    "$diretorio_casos_gerados/zero-geracoes-1x1.txt"
    "$diretorio_casos_gerados/uma-geracao-1x5.txt"
    "$diretorio_casos_gerados/duas-geracoes-5x1.txt"
    "$diretorio_casos_gerados/tres-geracoes-7x9.txt"
    "$diretorio_casos_gerados/uma-thread-por-linha-8x7.txt"
    "$raiz_projeto/entradas/classicos/bloco.txt"
    "$raiz_projeto/entradas/classicos/planador.txt"
    "$raiz_projeto/entradas/classicos/pulsar.txt"
    "$raiz_projeto/entradas/aleatorias/quadrada-5x5-d20-s1.txt"
    "$raiz_projeto/entradas/aleatorias/quadrada-10x10-d50-s13.txt"
    "$raiz_projeto/entradas/aleatorias/quadrada-80x80-d25-s302.txt"
    "$raiz_projeto/entradas/aleatorias/horizontal-30x90-d50-s403.txt"
    "$raiz_projeto/entradas/aleatorias/vertical-90x30-d50-s503.txt"
    "$raiz_projeto/entradas/aleatorias/quadrada-256x256-d10-s602.txt"
)

read -r -a quantidades_threads <<< "$threads_lista"

if ((${#quantidades_threads[@]} == 0)); then
    printf 'THREADS_LISTA deve informar ao menos um valor.\n' >&2
    exit 1
fi

declare -A threads_informadas=()

for quantidade_threads in "${quantidades_threads[@]}"; do
    if [[ ! "$quantidade_threads" =~ ^[1-9][0-9]*$ ]]; then
        printf 'THREADS_LISTA deve conter apenas inteiros maiores que zero.\n' >&2
        exit 1
    fi

    if [[ -n "${threads_informadas[$quantidade_threads]:-}" ]]; then
        printf 'THREADS_LISTA não pode conter valores repetidos.\n' >&2
        exit 1
    fi

    threads_informadas[$quantidade_threads]=1
done

if [[ -z "${threads_informadas[1]:-}" ]]; then
    printf 'THREADS_LISTA deve incluir 1 para validar o baseline Pthreads.\n' >&2
    exit 1
fi

for quantidade_threads in 2 4 8; do
    if [[ -z "${threads_informadas[$quantidade_threads]:-}" ]]; then
        quantidades_threads+=("$quantidade_threads")
        threads_informadas[$quantidade_threads]=1
    fi
done

for binario in "$binario_sequencial" "$binario_paralelo"; do
    if [[ ! -x "$binario" ]]; then
        printf 'Executável não encontrado em %s.\n' "$binario" >&2
        exit 1
    fi
done

comparacoes=0

for indice in "${!entradas[@]}"; do
    entrada="${entradas[$indice]}"

    if [[ ! -f "$entrada" ]]; then
        printf 'Entrada de validação não encontrada em %s.\n' "$entrada" >&2
        exit 1
    fi

    if [[ "$entrada" == "$diretorio_casos_gerados/"* ]]; then
        entrada_relativa="casos-gerados/$(basename "$entrada")"
    else
        entrada_relativa="${entrada#"$raiz_projeto/"}"
    fi
    linhas="$(sed -n '2s/[[:space:]].*//p' "$entrada")"
    saida_sequencial="$diretorio_temporario/sequencial-${indice}.txt"

    "$binario_sequencial" "$entrada" > "$saida_sequencial"

    for quantidade_threads in "${quantidades_threads[@]}"; do
        if ((quantidade_threads > linhas)); then
            continue
        fi

        saida_paralela="$diretorio_temporario/paralelo-${indice}-${quantidade_threads}.txt"
        "$binario_paralelo" "$entrada" "$quantidade_threads" \
            > "$saida_paralela"

        if ! cmp -s "$saida_sequencial" "$saida_paralela"; then
            printf 'Saída divergente em %s com %d thread(s).\n' \
                "$entrada_relativa" \
                "$quantidade_threads" \
                >&2
            diff -u "$saida_sequencial" "$saida_paralela" \
                | sed -n '1,120p' \
                >&2
            exit 1
        fi

        ((comparacoes += 1))
        printf 'Saída idêntica | Entrada=%s | Threads=%d\n' \
            "$entrada_relativa" \
            "$quantidade_threads"
    done
done

printf 'Validação funcional concluída: %d comparações idênticas.\n' \
    "$comparacoes"
