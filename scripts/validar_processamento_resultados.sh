#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
processador_resultados="$diretorio_script/processar_resultados_experimentos.sh"
fixture_execucoes="$raiz_projeto/testes/fixtures/execucoes_processamento.csv"
diretorio_temporario=""

limpar_temporarios()
{
    if [[ -n "$diretorio_temporario" && -d "$diretorio_temporario" ]]; then
        rm -rf -- "$diretorio_temporario"
    fi
}

trap limpar_temporarios EXIT

if [[ ! -f "$processador_resultados" ]]; then
    printf 'Processador de resultados não encontrado em %s.\n' \
        "$processador_resultados" \
        >&2
    exit 1
fi

if [[ ! -f "$fixture_execucoes" ]]; then
    printf 'Fixture de execuções não encontrada em %s.\n' \
        "$fixture_execucoes" \
        >&2
    exit 1
fi

diretorio_temporario="$(mktemp -d)"
cp "$fixture_execucoes" "$diretorio_temporario/execucoes.csv"

REPETICOES=1 bash "$processador_resultados" \
    "$diretorio_temporario" \
    4 \
    3 \
    > /dev/null

arquivo_resumo="$diretorio_temporario/resumo_desempenho.csv"

if [[ ! -f "$arquivo_resumo" ]]; then
    printf 'O pós-processamento não gerou o resumo esperado.\n' >&2
    exit 1
fi

awk -F, '
    NR == 1 {
        if (NF != 32) {
            printf "Cabeçalho da fixture com %d de 32 colunas.\n", NF \
                > "/dev/stderr"
            erro = 1
        }

        next
    }

    {
        quantidade++
        threads[$6]++
    }

    END {
        if (quantidade != 3) {
            printf "Resumo da fixture com %d de 3 configurações.\n", quantidade \
                > "/dev/stderr"
            erro = 1
        }

        if (threads[1] != 1 || threads[2] != 1 || threads[4] != 1) {
            print "Resumo da fixture com configurações inesperadas." \
                > "/dev/stderr"
            erro = 1
        }

        exit erro
    }
' "$arquivo_resumo"

printf 'Pós-processamento dos experimentos validado de ponta a ponta.\n'
