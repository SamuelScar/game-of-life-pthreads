#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
diretorio_resultados="$raiz_projeto/resultados"
arquivo_resultados="$diretorio_resultados/sequencial/execucoes.csv"
arquivo_inicio="$diretorio_resultados/inicio_execucao.txt"
arquivo_relatorio="$diretorio_resultados/resumo_execucao.md"

mkdir -p "$diretorio_resultados"

inicio_iso="indisponivel"
inicio_epoch=""

if [[ -f "$arquivo_inicio" ]]; then
    inicio_iso="$(sed -n '1p' "$arquivo_inicio")"
    inicio_epoch="$(sed -n '2p' "$arquivo_inicio")"
fi

fim_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fim_epoch="$(date +%s)"
duracao_total="indisponivel"

if [[ "$inicio_epoch" =~ ^[0-9]+$ ]]; then
    duracao_total="$((fim_epoch - inicio_epoch)) segundos"
fi

modelo_cpu="$(
    awk -F: '/model name/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }' \
        /proc/cpuinfo
)"
modelo_cpu="${modelo_cpu:-indisponivel}"
cpus_logicas="$(nproc)"
memoria_total="$(
    awk '/MemTotal/ { printf "%.2f GiB", $2 / 1048576 }' /proc/meminfo
)"
sistema_operacional="indisponivel"

if [[ -r /etc/os-release ]]; then
    sistema_operacional="$(. /etc/os-release && printf '%s' "$PRETTY_NAME")"
fi

versao_gcc="$(gcc --version 2>/dev/null | sed -n '1p' || true)"
versao_gcc="${versao_gcc:-indisponivel}"
status_execucao="${STATUS_EXECUCAO:-concluida}"
quantidade_execucoes=0

if [[ -f "$arquivo_resultados" ]]; then
    quantidade_execucoes="$(
        awk 'END { print (NR > 0 ? NR - 1 : 0) }' "$arquivo_resultados"
    )"
fi

{
    printf '# Resumo da execução dos experimentos\n\n'
    printf -- '- Status: `%s`\n' "$status_execucao"
    printf -- '- Início: `%s`\n' "$inicio_iso"
    printf -- '- Término: `%s`\n' "$fim_iso"
    printf -- '- Duração total: `%s`\n' "$duracao_total"
    printf -- '- Execuções sequenciais: `%d`\n\n' "$quantidade_execucoes"

    printf '## Ambiente de execução\n\n'
    printf '| Propriedade | Valor |\n'
    printf '|---|---|\n'
    printf '| Sistema operacional | %s |\n' "$sistema_operacional"
    printf '| Kernel | %s |\n' "$(uname -sr)"
    printf '| Arquitetura | %s |\n' "$(uname -m)"
    printf '| Processador | %s |\n' "$modelo_cpu"
    printf '| Processadores lógicos | %s |\n' "$cpus_logicas"
    printf '| Memória total | %s |\n' "$memoria_total"
    printf '| Compilador | %s |\n' "$versao_gcc"

    if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
        printf '| Repositório | %s |\n' "${GITHUB_REPOSITORY:-indisponivel}"
        printf '| Commit | `%s` |\n' "${GITHUB_SHA:-indisponivel}"
        printf '| Execução do Actions | %s, tentativa %s |\n' \
            "${GITHUB_RUN_ID:-indisponivel}" \
            "${GITHUB_RUN_ATTEMPT:-indisponivel}"
        printf '| Runner | %s |\n' "${RUNNER_NAME:-indisponivel}"
    fi

    printf '\n## Resultados sequenciais\n\n'

    if [[ -s "$arquivo_resultados" ]]; then
        printf '| Linhas | Colunas | Gerações | Densidade | Semente | Células iniciais | Rodadas | Média (s) | Desvio-padrão (s) | Mínimo (s) | Máximo (s) |\n'
        printf '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n'
        awk -F, '
            NR > 1 {
                chave = $1 SUBSEP $2 SUBSEP $3 SUBSEP $4 SUBSEP $5 SUBSEP $7
                quantidade[chave]++
                soma[chave] += $8
                soma_quadrados[chave] += $8 * $8

                if (!(chave in minimo) || $8 < minimo[chave])
                    minimo[chave] = $8

                if (!(chave in maximo) || $8 > maximo[chave])
                    maximo[chave] = $8
            }

            END {
                for (chave in quantidade) {
                    split(chave, campos, SUBSEP)
                    media = soma[chave] / quantidade[chave]
                    variancia = quantidade[chave] > 1 \
                        ? (soma_quadrados[chave] - quantidade[chave] * media * media) / (quantidade[chave] - 1) \
                        : 0
                    desvio_padrao = variancia > 0 ? sqrt(variancia) : 0
                    printf "%d,%d,%d,%d,%d,%d,%d,%.9f,%.9f,%.9f,%.9f\n",
                        campos[1],
                        campos[2],
                        campos[3],
                        campos[4],
                        campos[5],
                        campos[6],
                        quantidade[chave],
                        media,
                        desvio_padrao,
                        minimo[chave],
                        maximo[chave]
                }
            }
        ' "$arquivo_resultados" \
            | sort -t, -k1,1n -k2,2n \
            | awk -F, '{
                printf "| %d | %d | %d | %d%% | %d | %d | %d | %.9f | %.9f | %.9f | %.9f |\n",
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
            }'
    else
        printf 'Nenhum resultado sequencial foi encontrado.\n'
    fi

    printf '\n## Observações\n\n'
    printf -- '- Os tempos incluem somente a simulação das gerações.\n'
    printf -- '- A leitura da entrada e a escrita do estado final não fazem parte da medição.\n'
    printf -- '- As entradas são determinísticas e usam a mesma semente em todas as rodadas.\n'
    printf -- '- O desvio-padrão amostral indica a variação dos tempos entre as rodadas.\n'
    printf -- '- Speedup e eficiência serão calculados após a implementação paralela.\n'
} > "$arquivo_relatorio"

printf 'Relatorio gerado em %s\n' "$arquivo_relatorio"
