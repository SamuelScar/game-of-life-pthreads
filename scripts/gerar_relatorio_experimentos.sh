#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
diretorio_resultados="$raiz_projeto/resultados"
arquivo_resultados_sequencial="$diretorio_resultados/sequencial/execucoes.csv"
arquivo_resultados_completo="$diretorio_resultados/experimentos_completos/execucoes.csv"
arquivo_resumo_paralelo="$diretorio_resultados/experimentos_completos/resumo_desempenho.csv"
arquivo_ambiente_paralelo="$diretorio_resultados/experimentos_completos/ambiente_execucao.txt"
arquivo_inicio="$diretorio_resultados/sequencial/inicio_execucao.txt"
arquivo_relatorio="$diretorio_resultados/relatorio_experimentos.md"
arquivo_resultados="$arquivo_resultados_sequencial"
coluna_versao=0

if [[ -f "$arquivo_resultados_completo" ]]; then
    arquivo_resultados="$arquivo_resultados_completo"
    coluna_versao=30
fi

mkdir -p "$diretorio_resultados"

inicio_iso="indisponivel"
inicio_epoch=""

if ((coluna_versao == 30)) && [[ -f "$arquivo_ambiente_paralelo" ]]; then
    inicio_iso="$(awk -F= '$1 == "inicio_utc" { print $2; exit }' "$arquivo_ambiente_paralelo")"
    inicio_epoch="$(awk -F= '$1 == "inicio_epoch" { print $2; exit }' "$arquivo_ambiente_paralelo")"
elif [[ -f "$arquivo_inicio" ]]; then
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
status_perfil="${STATUS_PERFIL:-nao_informado}"
cache_condicionada=indisponivel
cache_condicionamento_bytes=indisponivel
quantidade_execucoes=0
quantidade_execucoes_paralelas=0
quantidade_entradas=0

if [[ -f "$arquivo_resultados" ]]; then
    quantidade_execucoes="$(
        awk -F, -v coluna_versao="$coluna_versao" '
            NR > 1 && (coluna_versao == 0 || $coluna_versao == "sequencial") {
                quantidade++
            }

            END { print quantidade + 0 }
        ' "$arquivo_resultados"
    )"
    quantidade_entradas="$(
        awk -F, -v coluna_versao="$coluna_versao" '
            NR > 1 \
                && (coluna_versao == 0 || $coluna_versao == "sequencial") \
                && !($1 in entradas) {
                entradas[$1] = 1
                quantidade++
            }

            END { print quantidade + 0 }
        ' \
            "$arquivo_resultados"
    )"
fi

if [[ -f "$arquivo_resultados_completo" ]]; then
    quantidade_execucoes_paralelas="$(
        awk -F, 'NR > 1 && $30 == "paralelo" { quantidade++ }
            END { print quantidade + 0 }
        ' "$arquivo_resultados_completo"
    )"
fi

if ((coluna_versao == 30)) && [[ -f "$arquivo_ambiente_paralelo" ]]; then
    cache_condicionada="$(
        awk -F= '$1 == "cache_condicionada" { print $2; exit }' \
            "$arquivo_ambiente_paralelo"
    )"
    cache_condicionamento_bytes="$(
        awk -F= '$1 == "cache_condicionamento_bytes" { print $2; exit }' \
            "$arquivo_ambiente_paralelo"
    )"
elif [[ -f "$arquivo_inicio" ]]; then
    cache_condicionada="$(
        awk -F= '$1 == "cache_condicionada" { print $2; exit }' \
            "$arquivo_inicio"
    )"
    cache_condicionamento_bytes="$(
        awk -F= '$1 == "cache_condicionamento_bytes" { print $2; exit }' \
            "$arquivo_inicio"
    )"
fi

cache_condicionada="${cache_condicionada:-indisponivel}"
cache_condicionamento_bytes="${cache_condicionamento_bytes:-indisponivel}"

{
    printf '# Resumo da execução dos experimentos\n\n'
    printf -- '- Status: `%s`\n' "$status_execucao"
    printf -- '- Início: `%s`\n' "$inicio_iso"
    printf -- '- Término: `%s`\n' "$fim_iso"
    printf -- '- Duração total: `%s`\n' "$duracao_total"
    printf -- '- Entradas predefinidas: `%d`\n' "$quantidade_entradas"
    printf -- '- Execuções sequenciais: `%d`\n' "$quantidade_execucoes"
    printf -- '- Execuções paralelas: `%d`\n' "$quantidade_execucoes_paralelas"
    printf -- '- Perfil detalhado: `%s`\n\n' "$status_perfil"

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
    printf '| Cache condicionada antes de cada medição | %s |\n' \
        "$cache_condicionada"
    printf '| Buffer de condicionamento da cache (bytes) | %s |\n' \
        "$cache_condicionamento_bytes"

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
        printf '| Entrada | Categoria | Linhas | Colunas | Gerações | Células iniciais | Rodadas | Simulação média (s) | Desvio-padrão (s) | Mínimo (s) | Máximo (s) | RSS máximo médio (MiB) | Falhas maiores médias | Falhas menores médias | Trocas voluntárias médias | Trocas involuntárias médias |\n'
        printf '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n'
        awk -F, -v coluna_versao="$coluna_versao" '
            NR > 1 && (coluna_versao == 0 || $coluna_versao == "sequencial") {
                chave = $1 SUBSEP $2 SUBSEP $3 SUBSEP $4 SUBSEP $5 SUBSEP $7
                quantidade[chave]++
                soma[chave] += $10
                soma_quadrados[chave] += $10 * $10
                soma_rss[chave] += $15
                soma_falhas_maiores[chave] += $22
                soma_falhas_menores[chave] += $23
                soma_trocas_voluntarias[chave] += $25
                soma_trocas_involuntarias[chave] += $26

                if (!(chave in minimo) || $10 < minimo[chave])
                    minimo[chave] = $10

                if (!(chave in maximo) || $10 > maximo[chave])
                    maximo[chave] = $10
            }

            END {
                for (chave in quantidade) {
                    split(chave, campos, SUBSEP)
                    media = soma[chave] / quantidade[chave]
                    variancia = quantidade[chave] > 1 \
                        ? (soma_quadrados[chave] - quantidade[chave] * media * media) / (quantidade[chave] - 1) \
                        : 0
                    desvio_padrao = variancia > 0 ? sqrt(variancia) : 0
                    printf "%s,%s,%d,%d,%d,%d,%d,%.9f,%.9f,%.9f,%.9f,%.3f,%.3f,%.3f,%.3f,%.3f\n",
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
                        maximo[chave],
                        soma_rss[chave] / quantidade[chave] / 1024,
                        soma_falhas_maiores[chave] / quantidade[chave],
                        soma_falhas_menores[chave] / quantidade[chave],
                        soma_trocas_voluntarias[chave] / quantidade[chave],
                        soma_trocas_involuntarias[chave] / quantidade[chave]
                }
            }
        ' "$arquivo_resultados" \
            | sort -t, -k2,2 -k1,1 \
            | awk -F, '{
                printf "| `%s` | %s | %d | %d | %d | %d | %d | %.9f | %.9f | %.9f | %.9f | %.3f | %.3f | %.3f | %.3f | %.3f |\n",
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
            }'
    else
        printf 'Nenhum resultado sequencial foi encontrado.\n'
    fi

    printf '\n## Resultados paralelos\n\n'

    if [[ -s "$arquivo_resumo_paralelo" ]]; then
        printf '| Entrada | Linhas | Colunas | Threads | Rodadas | Sequencial médio (s) | Mediana sequencial (s) | Paralelo médio (s) | Mediana paralela (s) | Speedup sequencial | Speedup Pthreads 1 | Eficiência sequencial | Eficiência Pthreads 1 | CPU média | Núcleos médios | RSS máximo médio (MiB) | Oversubscription | Linhas por worker |\n'
        printf '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|\n'
        awk -F, 'NR > 1 {
            printf "| `%s` | %d | %d | %d | %d | %.9f | %.9f | %.9f | %.9f | %.6f | %.6f | %.2f%% | %.2f%% | %.3f%% | %.3f | %.3f | %s | %d-%d |\n",
                $1, $3, $4, $6, $7, $8, $27, $12, $28, $16, $30, $18, $32, $19, $20, $21, $24, $25, $26
        }' "$arquivo_resumo_paralelo"
    else
        printf 'Nenhum resultado paralelo foi encontrado.\n'
    fi

    printf '\n## Perfil detalhado\n\n'

    if [[ -f "$diretorio_resultados/perfil_sequencial/entrada.txt" ]]; then
        printf -- '- Entrada analisada: `%s`\n' \
            "$(< "$diretorio_resultados/perfil_sequencial/entrada.txt")"
        printf -- '- Cachegrind: referências a instruções e dados, faltas de cache e desvios de fluxo.\n'
        printf -- '- Massif: evolução e pico do uso de heap e pilha.\n'
        if [[ -s "$diretorio_resultados/perfil_sequencial/gprof.txt" ]]; then
            printf -- '- gprof: tempo de CPU e quantidade de chamadas por função.\n'
        fi
        printf -- '- Assembly: instruções geradas e registradores escolhidos pelo compilador.\n'
        printf -- '- Sistema: topologia de caches e snapshots de RAM e memória virtual.\n'

        if [[ -s "$diretorio_resultados/perfil_sequencial/caches.csv" ]]; then
            printf '\n### Hierarquia de caches\n\n'
            printf '| Índice | Nível | Tipo | Tamanho | Linha (bytes) | Conjuntos | Vias | CPUs compartilhadas |\n'
            printf '|---|---:|---|---:|---:|---:|---:|---|\n'
            awk -F, 'NR > 1 {
                printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n",
                    $1, $2, $3, $4, $5, $6, $7, $8
            }' "$diretorio_resultados/perfil_sequencial/caches.csv"
        fi
    else
        printf 'O perfil detalhado não foi coletado.\n'
    fi

    printf '\n## Observações\n\n'
    printf -- '- Os tempos incluem somente a simulação das gerações.\n'
    printf -- '- O condicionamento da cache ocorre antes do processo medido e não entra no tempo da simulação.\n'
    printf -- '- A ordem das entradas e configurações varia entre as rodadas; o CSV registra a posição e a execução precedente.\n'
    printf -- '- A leitura da entrada e a escrita do estado final não fazem parte da medição.\n'
    printf -- '- As entradas são arquivos predefinidos e versionados no repositório.\n'
    printf -- '- O CSV completo contém métricas de memória, CPU, paginação, contexto e I/O por execução.\n'
    printf -- '- As métricas do Cachegrind representam uma simulação dos caches, não contadores físicos do processador.\n'
    printf -- '- O desvio-padrão amostral indica a variação dos tempos entre as rodadas.\n'
    printf -- '- A mediana reduz a influência de medições atípicas na interpretação.\n'
    printf -- '- O speedup é a média sequencial dividida pela média paralela da mesma entrada.\n'
    printf -- '- A eficiência é o speedup dividido pela quantidade de threads.\n'
    printf -- '- O speedup Pthreads 1 compara cada configuração com a versão Pthreads de uma thread.\n'
    printf -- '- Configurações com mais threads que processadores lógicos disponíveis são marcadas como oversubscription.\n'
} > "$arquivo_relatorio"

printf 'Relatorio gerado em %s\n' "$arquivo_relatorio"
