#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"

validar_inteiro_positivo()
{
    local nome="$1"
    local valor="$2"

    if [[ ! "$valor" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s deve ser um inteiro maior que zero.\n' "$nome" >&2
        exit 1
    fi
}

contar_registros_csv()
{
    local arquivo="$1"

    awk 'END { print (NR > 0 ? NR - 1 : 0) }' "$arquivo"
}

validar_execucoes()
{
    local arquivo_execucoes="$1"
    local permitir_vazio="${2:-0}"

    awk -F, -v permitir_vazio="$permitir_vazio" '
        NR == 1 {
            if (NF != 39) {
                printf "Cabeçalho completo com %d de 39 colunas.\n", NF \
                    > "/dev/stderr"
                erro = 1
            }

            next
        }

        {
            if (NF != 39) {
                printf "Linha %d do CSV completo com %d de 39 colunas.\n", \
                    NR, NF > "/dev/stderr"
                erro = 1
            }

            if ($35 != NR - 1) {
                printf "Ordem de execução inválida na linha %d.\n", NR \
                    > "/dev/stderr"
                erro = 1
            }

            if (($38 == "sim" && $39 <= 0) ||
                ($38 == "nao" && $39 != 0)) {
                printf "Condicionamento de cache inconsistente na linha %d.\n", NR \
                    > "/dev/stderr"
                erro = 1
            }
        }

        END {
            if (NR == 0 && !permitir_vazio) {
                print "O CSV de execuções está vazio." > "/dev/stderr"
                erro = 1
            }

            exit erro
        }
    ' "$arquivo_execucoes"
}

validar_repeticoes()
{
    local arquivo_execucoes="$1"
    local repeticoes="$2"

    awk -F, -v repeticoes="$repeticoes" '
        NR == 1 { next }

        {
            chave = $1 SUBSEP $30 SUBSEP $31
            quantidade[chave]++
        }

        END {
            for (chave in quantidade) {
                if (quantidade[chave] != repeticoes) {
                    split(chave, campos, SUBSEP)
                    printf "Quantidade de repetições inválida para %s, versão %s, com %s thread(s): %d de %d.\n", \
                        campos[1], campos[2], campos[3], quantidade[chave], repeticoes \
                        > "/dev/stderr"
                    erro = 1
                }
            }

            exit erro
        }
    ' "$arquivo_execucoes"
}

gerar_resumo()
{
    local arquivo_execucoes="$1"
    local arquivo_resumo="$2"

    {
        printf '%s\n' \
            'entrada,categoria,linhas,colunas,geracoes,threads,repeticoes,media_sequencial_segundos,desvio_sequencial_segundos,minimo_sequencial_segundos,maximo_sequencial_segundos,media_paralela_segundos,desvio_paralelo_segundos,minimo_paralelo_segundos,maximo_paralelo_segundos,speedup,eficiencia,eficiencia_percentual,cpu_paralela_media_percentual,nucleos_cpu_medios,rss_maximo_paralelo_medio_mib,custo_paralelo_segundos,sobrecusto_segundos,oversubscription,linhas_min_worker,linhas_max_worker,mediana_sequencial_segundos,mediana_paralela_segundos,media_pthreads_1_segundos,speedup_vs_pthreads_1,eficiencia_vs_pthreads_1,eficiencia_vs_pthreads_1_percentual'

        awk -F, '
            function calcular_mediana(chave, quantidade, valores, copia, i, j, temporario) {
                for (i in copia)
                    delete copia[i]

                for (i = 1; i <= quantidade; i++)
                    copia[i] = valores[chave SUBSEP i]

                for (i = 2; i <= quantidade; i++) {
                    temporario = copia[i]
                    j = i - 1

                    while (j >= 1 && copia[j] > temporario) {
                        copia[j + 1] = copia[j]
                        j--
                    }

                    copia[j + 1] = temporario
                }

                if (quantidade % 2 == 1)
                    return copia[(quantidade + 1) / 2]

                return (copia[quantidade / 2] + copia[quantidade / 2 + 1]) / 2
            }

            NR > 1 && $30 == "sequencial" {
                soma_sequencial[$1] += $10
                soma_quadrados_sequencial[$1] += $10 * $10
                quantidade_sequencial[$1]++
                tempos_sequenciais[$1 SUBSEP quantidade_sequencial[$1]] = $10
                categoria[$1] = $2
                linhas[$1] = $3
                colunas[$1] = $4
                geracoes[$1] = $5

                if (!($1 in minimo_sequencial) || $10 < minimo_sequencial[$1])
                    minimo_sequencial[$1] = $10

                if (!($1 in maximo_sequencial) || $10 > maximo_sequencial[$1])
                    maximo_sequencial[$1] = $10
            }

            NR > 1 && $30 == "paralelo" {
                chave = $1 SUBSEP $31
                soma_paralela[chave] += $10
                soma_quadrados_paralela[chave] += $10 * $10
                soma_cpu_paralela[chave] += $14
                soma_rss_paralela[chave] += $15
                quantidade_paralela[chave]++
                tempos_paralelos[chave SUBSEP quantidade_paralela[chave]] = $10
                oversubscription[chave] = $32
                linhas_min_worker[chave] = $33
                linhas_max_worker[chave] = $34

                if (!(chave in minimo_paralelo) || $10 < minimo_paralelo[chave])
                    minimo_paralelo[chave] = $10

                if (!(chave in maximo_paralelo) || $10 > maximo_paralelo[chave])
                    maximo_paralelo[chave] = $10
            }

            END {
                for (chave in quantidade_paralela) {
                    split(chave, campos, SUBSEP)
                    entrada = campos[1]
                    threads = campos[2]
                    chave_pthreads_1 = entrada SUBSEP 1
                    media_sequencial = soma_sequencial[entrada] / quantidade_sequencial[entrada]
                    media_paralela = soma_paralela[chave] / quantidade_paralela[chave]
                    media_pthreads_1 = soma_paralela[chave_pthreads_1] / quantidade_paralela[chave_pthreads_1]
                    variancia_sequencial = quantidade_sequencial[entrada] > 1 \
                        ? (soma_quadrados_sequencial[entrada] - quantidade_sequencial[entrada] * media_sequencial * media_sequencial) / (quantidade_sequencial[entrada] - 1) \
                        : 0
                    variancia_paralela = quantidade_paralela[chave] > 1 \
                        ? (soma_quadrados_paralela[chave] - quantidade_paralela[chave] * media_paralela * media_paralela) / (quantidade_paralela[chave] - 1) \
                        : 0
                    desvio_sequencial = variancia_sequencial > 0 ? sqrt(variancia_sequencial) : 0
                    desvio_paralelo = variancia_paralela > 0 ? sqrt(variancia_paralela) : 0
                    mediana_sequencial = calcular_mediana(entrada, quantidade_sequencial[entrada], tempos_sequenciais)
                    mediana_paralela = calcular_mediana(chave, quantidade_paralela[chave], tempos_paralelos)
                    speedup = media_paralela > 0 ? media_sequencial / media_paralela : 0
                    eficiencia = threads > 0 ? speedup / threads : 0
                    speedup_pthreads_1 = media_paralela > 0 ? media_pthreads_1 / media_paralela : 0
                    eficiencia_pthreads_1 = threads > 0 ? speedup_pthreads_1 / threads : 0
                    cpu_media = soma_cpu_paralela[chave] / quantidade_paralela[chave]
                    rss_medio_mib = soma_rss_paralela[chave] / quantidade_paralela[chave] / 1024
                    custo_paralelo = threads * media_paralela
                    sobrecusto = custo_paralelo - media_sequencial

                    printf "%s,%s,%d,%d,%d,%d,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.6f,%.6f,%.2f,%.3f,%.3f,%.3f,%.9f,%.9f,%s,%d,%d,%.9f,%.9f,%.9f,%.6f,%.6f,%.2f\n", \
                        entrada,
                        categoria[entrada],
                        linhas[entrada],
                        colunas[entrada],
                        geracoes[entrada],
                        threads,
                        quantidade_paralela[chave],
                        media_sequencial,
                        desvio_sequencial,
                        minimo_sequencial[entrada],
                        maximo_sequencial[entrada],
                        media_paralela,
                        desvio_paralelo,
                        minimo_paralelo[chave],
                        maximo_paralelo[chave],
                        speedup,
                        eficiencia,
                        eficiencia * 100,
                        cpu_media,
                        cpu_media / 100,
                        rss_medio_mib,
                        custo_paralelo,
                        sobrecusto,
                        oversubscription[chave],
                        linhas_min_worker[chave],
                        linhas_max_worker[chave],
                        mediana_sequencial,
                        mediana_paralela,
                        media_pthreads_1,
                        speedup_pthreads_1,
                        eficiencia_pthreads_1,
                        eficiencia_pthreads_1 * 100
                }
            }
        ' "$arquivo_execucoes" | sort -t, -k1,1 -k6,6n
    } > "$arquivo_resumo"
}

validar_resumo()
{
    local arquivo_resumo="$1"

    awk -F, '
        function absoluto(valor) {
            return valor < 0 ? -valor : valor
        }

        NR == 1 {
            if (NF != 32) {
                printf "Cabeçalho do resumo com %d de 32 colunas.\n", NF \
                    > "/dev/stderr"
                erro = 1
            }

            next
        }

        {
            if (NF != 32) {
                printf "Linha %d do resumo com %d de 32 colunas.\n", NR, NF \
                    > "/dev/stderr"
                erro = 1
            }

            if ($12 <= 0 || absoluto($16 - $8 / $12) > 0.00001) {
                printf "Speedup inconsistente na linha %d do resumo.\n", NR \
                    > "/dev/stderr"
                erro = 1
            }

            if ($6 <= 0 || absoluto($17 - $16 / $6) > 0.00001) {
                printf "Eficiência inconsistente na linha %d do resumo.\n", NR \
                    > "/dev/stderr"
                erro = 1
            }

            if ($12 <= 0 || absoluto($30 - $29 / $12) > 0.00001) {
                printf "Speedup Pthreads 1 inconsistente na linha %d.\n", NR \
                    > "/dev/stderr"
                erro = 1
            }

            entradas[$1] = 1

            if ($6 == 1)
                possui_pthreads_1[$1] = 1
        }

        END {
            for (entrada in entradas) {
                if (!(entrada in possui_pthreads_1)) {
                    printf "Baseline Pthreads 1 ausente para %s.\n", entrada \
                        > "/dev/stderr"
                    erro = 1
                }
            }

            exit erro
        }
    ' "$arquivo_resumo"
}

verificar_sintaxe_awk()
{
    local diretorio_temporario
    local resumo_temporario

    diretorio_temporario="$(mktemp -d)"
    resumo_temporario="$diretorio_temporario/resumo.csv"

    contar_registros_csv /dev/null > /dev/null
    validar_execucoes /dev/null 1
    validar_repeticoes /dev/null 1
    gerar_resumo /dev/null "$resumo_temporario"
    validar_resumo "$resumo_temporario"

    rm -f "$resumo_temporario"
    rmdir "$diretorio_temporario"

    printf 'Sintaxe dos processadores AWK validada.\n'
}

if [[ "${1:-}" == "--verificar-sintaxe" ]]; then
    verificar_sintaxe_awk
    exit 0
fi

diretorio_resultados="${1:-$raiz_projeto/resultados/experimentos_completos}"
total_execucoes_esperado="${2:-}"
total_resumos_esperado="${3:-}"
arquivo_execucoes="$diretorio_resultados/execucoes.csv"
arquivo_resumo="$diretorio_resultados/resumo_desempenho.csv"
arquivo_ambiente="$diretorio_resultados/ambiente_execucao.txt"
arquivo_resumo_temporario=""

if [[ ! -f "$arquivo_execucoes" ]]; then
    printf 'CSV de execuções não encontrado em %s.\n' "$arquivo_execucoes" >&2
    exit 1
fi

repeticoes="${REPETICOES:-}"

if [[ -z "$repeticoes" && -f "$arquivo_ambiente" ]]; then
    repeticoes="$(awk -F= '$1 == "repeticoes" { print $2; exit }' "$arquivo_ambiente")"
fi

validar_inteiro_positivo REPETICOES "$repeticoes"

if [[ -n "$total_execucoes_esperado" ]]; then
    validar_inteiro_positivo TOTAL_EXECUCOES_ESPERADO "$total_execucoes_esperado"
fi

if [[ -n "$total_resumos_esperado" ]]; then
    validar_inteiro_positivo TOTAL_RESUMOS_ESPERADO "$total_resumos_esperado"
fi

linhas_registradas="$(contar_registros_csv "$arquivo_execucoes")"

if [[ -n "$total_execucoes_esperado" ]] \
    && ((linhas_registradas != total_execucoes_esperado)); then
    printf 'Foram registradas %d de %d execuções planejadas.\n' \
        "$linhas_registradas" \
        "$total_execucoes_esperado" \
        >&2
    exit 1
fi

validar_execucoes "$arquivo_execucoes"
validar_repeticoes "$arquivo_execucoes" "$repeticoes"

arquivo_resumo_temporario="$(mktemp "$diretorio_resultados/.resumo-desempenho.XXXXXX")"
trap 'rm -f "$arquivo_resumo_temporario"' EXIT

gerar_resumo "$arquivo_execucoes" "$arquivo_resumo_temporario"
validar_resumo "$arquivo_resumo_temporario"

linhas_resumo="$(contar_registros_csv "$arquivo_resumo_temporario")"

if [[ -n "$total_resumos_esperado" ]] \
    && ((linhas_resumo != total_resumos_esperado)); then
    printf 'O resumo contém %d de %d configurações paralelas esperadas.\n' \
        "$linhas_resumo" \
        "$total_resumos_esperado" \
        >&2
    exit 1
fi

mv "$arquivo_resumo_temporario" "$arquivo_resumo"
arquivo_resumo_temporario=""

printf '%s\n' \
    'Processamento dos resultados concluído.' \
    "Execuções: $arquivo_execucoes" \
    "Resumo: $arquivo_resumo"
