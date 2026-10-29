#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario="$raiz_projeto/bin/sequencial"
diretorio_resultados="$raiz_projeto/resultados"
diretorio_entradas="$diretorio_resultados/entradas"
arquivo_resultados="$diretorio_resultados/sequencial/execucoes.csv"
arquivo_inicio="$diretorio_resultados/inicio_execucao.txt"
diretorio_temporario="$(mktemp -d)"

trap 'rm -rf "$diretorio_temporario"' EXIT

read -r -a tamanhos <<< "${TAMANHOS:-128 256 512 1024}"
geracoes="${GERACOES:-100}"
densidade="${DENSIDADE:-25}"
repeticoes="${REPETICOES:-5}"
semente="${SEMENTE:-42}"

validar_inteiro_positivo()
{
    local nome="$1"
    local valor="$2"

    if [[ ! "$valor" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s deve ser um inteiro maior que zero.\n' "$nome" >&2
        exit 1
    fi
}

validar_inteiro_positivo GERACOES "$geracoes"
validar_inteiro_positivo REPETICOES "$repeticoes"

if [[ ! "$densidade" =~ ^[0-9]+$ ]] || ((densidade < 0 || densidade > 100)); then
    printf 'DENSIDADE deve ser um inteiro entre 0 e 100.\n' >&2
    exit 1
fi

if [[ ! "$semente" =~ ^[0-9]+$ ]]; then
    printf 'SEMENTE deve ser um inteiro maior ou igual a zero.\n' >&2
    exit 1
fi

if ((${#tamanhos[@]} == 0)); then
    printf 'Informe pelo menos um tamanho de matriz.\n' >&2
    exit 1
fi

for tamanho in "${tamanhos[@]}"; do
    validar_inteiro_positivo TAMANHOS "$tamanho"
done

if [[ ! -x "$binario" ]]; then
    printf 'Executavel sequencial nao encontrado em %s.\n' "$binario" >&2
    exit 1
fi

mkdir -p "$diretorio_entradas" "$(dirname "$arquivo_resultados")"
rm -f "$diretorio_entradas"/*.txt

printf '%s\n%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$(date +%s)" \
    > "$arquivo_inicio"

printf '%s\n' \
    'linhas,colunas,geracoes,densidade,semente,rodada,celulas_vivas_iniciais,tempo_segundos' \
    > "$arquivo_resultados"

gerar_entrada()
{
    local tamanho="$1"
    local arquivo="$2"
    local quantidade_vivas

    quantidade_vivas="$(
        awk \
            -v linhas="$tamanho" \
            -v colunas="$tamanho" \
            -v percentual="$densidade" \
            -v seed="$semente" '
                BEGIN {
                    quantidade = 0

                    for (linha = 0; linha < linhas; linha++) {
                        for (coluna = 0; coluna < colunas; coluna++) {
                            hash = (linha * 73856093 + coluna * 19349663 + seed * 83492791) % 100
                            quantidade += hash < percentual
                        }
                    }

                    print quantidade
                }
            '
    )"

    {
        printf '%d\n' "$geracoes"
        printf '%d %d\n' "$tamanho" "$tamanho"
        printf '%d\n' "$quantidade_vivas"
        awk \
            -v linhas="$tamanho" \
            -v colunas="$tamanho" \
            -v percentual="$densidade" \
            -v seed="$semente" '
                BEGIN {
                    for (linha = 0; linha < linhas; linha++) {
                        for (coluna = 0; coluna < colunas; coluna++) {
                            hash = (linha * 73856093 + coluna * 19349663 + seed * 83492791) % 100

                            if (hash < percentual)
                                printf "%d %d\n", linha, coluna
                        }
                    }
                }
            '
    } > "$arquivo"

    printf '%s' "$quantidade_vivas"
}

total_execucoes=$((${#tamanhos[@]} * repeticoes))
printf 'Experimentos sequenciais planejados: %d\n' "$total_execucoes"
printf 'Gerações: %d | Densidade: %d%% | Repetições: %d | Semente: %d\n' \
    "$geracoes" "$densidade" "$repeticoes" "$semente"

for tamanho in "${tamanhos[@]}"; do
    arquivo_entrada="$diretorio_entradas/mundo-${tamanho}x${tamanho}.txt"
    quantidade_vivas="$(gerar_entrada "$tamanho" "$arquivo_entrada")"

    for ((rodada = 1; rodada <= repeticoes; rodada++)); do
        arquivo_erro="$diretorio_temporario/erro-${tamanho}-${rodada}.txt"
        printf 'Sequencial | Matriz=%dx%d | Gerações=%d | Rodada=%d/%d\n' \
            "$tamanho" "$tamanho" "$geracoes" "$rodada" "$repeticoes"

        if ! MEDIR_TEMPO=1 OMITIR_SAIDA=1 \
            "$binario" "$arquivo_entrada" \
            > /dev/null 2> "$arquivo_erro"; then
            sed 's/^/  /' "$arquivo_erro" >&2
            exit 1
        fi

        tempo="$(
            awk -F= '$1 == "tempo_segundos" { print $2; exit }' "$arquivo_erro"
        )"

        if [[ ! "$tempo" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            printf 'O tempo da execução não foi registrado corretamente.\n' >&2
            exit 1
        fi

        printf '%d,%d,%d,%d,%d,%d,%d,%s\n' \
            "$tamanho" \
            "$tamanho" \
            "$geracoes" \
            "$densidade" \
            "$semente" \
            "$rodada" \
            "$quantidade_vivas" \
            "$tempo" \
            >> "$arquivo_resultados"
    done
done

STATUS_EXECUCAO=sucesso bash "$diretorio_script/gerar_relatorio.sh"

printf '%s\n' \
    'Experimentos sequenciais finalizados.' \
    "Resultados: $arquivo_resultados" \
    "Relatório: $diretorio_resultados/resumo_execucao.md"
