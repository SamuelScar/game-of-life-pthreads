#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario_sequencial="$raiz_projeto/bin/sequencial"
binario_paralelo="$raiz_projeto/bin/paralelo"
diretorio_entradas="$raiz_projeto/entradas"
diretorio_resultados="$raiz_projeto/resultados/experimentos_completos"
arquivo_execucoes="$diretorio_resultados/execucoes.csv"
arquivo_resumo="$diretorio_resultados/resumo_desempenho.csv"
arquivo_ambiente="$diretorio_resultados/ambiente_execucao.txt"
diretorio_temporario="$(mktemp -d)"
processadores_logicos="$(nproc)"
inicio_epoch="$(date +%s)"

trap 'rm -rf "$diretorio_temporario"' EXIT

repeticoes="${REPETICOES:-5}"
threads_lista="${THREADS_LISTA:-1 2 4 8}"

validar_inteiro_positivo()
{
    local nome="$1"
    local valor="$2"

    if [[ ! "$valor" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s deve ser um inteiro maior que zero.\n' "$nome" >&2
        exit 1
    fi
}

validar_cabecalho()
{
    local arquivo="$1"
    local geracoes="$2"
    local linhas="$3"
    local colunas="$4"
    local quantidade_vivas="$5"

    if [[ ! "$geracoes" =~ ^[0-9]+$
        || ! "$linhas" =~ ^[1-9][0-9]*$
        || ! "$colunas" =~ ^[1-9][0-9]*$
        || ! "$quantidade_vivas" =~ ^[0-9]+$ ]] \
        || ((quantidade_vivas > linhas * colunas)); then
        printf 'Cabeçalho inválido em %s.\n' "$arquivo" >&2
        exit 1
    fi
}

registrar_execucao()
{
    local entrada_relativa="$1"
    local categoria="$2"
    local linhas="$3"
    local colunas="$4"
    local geracoes="$5"
    local quantidade_vivas="$6"
    local versao="$7"
    local quantidade_threads="$8"
    local rodada="$9"
    local arquivo_entrada="${10}"
    local tamanho_arquivo="${11}"
    local memoria_matrizes="${12}"
    local arquivo_erro
    local arquivo_metricas
    local tempo
    local tempo_usuario
    local tempo_sistema
    local tempo_parede
    local cpu_percentual
    local rss_maximo
    local rss_medio
    local memoria_total_media
    local dados_nao_compartilhados
    local pilha_media
    local texto_compartilhado
    local pagina_bytes
    local page_faults_maiores
    local page_faults_menores
    local swaps
    local trocas_contexto_voluntarias
    local trocas_contexto_involuntarias
    local leituras_sistema_arquivos
    local escritas_sistema_arquivos
    local status_saida
    local oversubscription=nao
    local linhas_min_worker=0
    local linhas_max_worker=0
    local -a comando

    arquivo_erro="$diretorio_temporario/${versao}-${quantidade_threads}-${rodada}.txt"
    arquivo_metricas="$diretorio_temporario/metricas-${versao}-${quantidade_threads}-${rodada}.csv"

    if [[ "$versao" == "sequencial" ]]; then
        comando=("$binario_sequencial" "$arquivo_entrada")
    else
        comando=("$binario_paralelo" "$arquivo_entrada" "$quantidade_threads")
        linhas_min_worker=$((linhas / quantidade_threads))
        linhas_max_worker=$(((linhas + quantidade_threads - 1) / quantidade_threads))

        if ((quantidade_threads > processadores_logicos)); then
            oversubscription=sim
        fi
    fi

    printf '%s | Entrada=%s | Matriz=%dx%d | Gerações=%d | Threads=%s | Rodada=%d/%d\n' \
        "$versao" \
        "$entrada_relativa" \
        "$linhas" \
        "$colunas" \
        "$geracoes" \
        "$quantidade_threads" \
        "$rodada" \
        "$repeticoes"

    if ! /usr/bin/time \
        --output="$arquivo_metricas" \
        --format='%U,%S,%e,%P,%M,%t,%K,%D,%p,%X,%Z,%F,%R,%W,%w,%c,%I,%O,%x' \
        env MEDIR_TEMPO=1 OMITIR_SAIDA=1 "${comando[@]}" \
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

    IFS=, read -r \
        tempo_usuario \
        tempo_sistema \
        tempo_parede \
        cpu_percentual \
        rss_maximo \
        rss_medio \
        memoria_total_media \
        dados_nao_compartilhados \
        pilha_media \
        texto_compartilhado \
        pagina_bytes \
        page_faults_maiores \
        page_faults_menores \
        swaps \
        trocas_contexto_voluntarias \
        trocas_contexto_involuntarias \
        leituras_sistema_arquivos \
        escritas_sistema_arquivos \
        status_saida \
        < "$arquivo_metricas"

    cpu_percentual="${cpu_percentual%\%}"

    printf '%s,%s,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%s,%d,%d\n' \
        "$entrada_relativa" \
        "$categoria" \
        "$linhas" \
        "$colunas" \
        "$geracoes" \
        "$rodada" \
        "$quantidade_vivas" \
        "$tamanho_arquivo" \
        "$memoria_matrizes" \
        "$tempo" \
        "$tempo_usuario" \
        "$tempo_sistema" \
        "$tempo_parede" \
        "$cpu_percentual" \
        "$rss_maximo" \
        "$rss_medio" \
        "$memoria_total_media" \
        "$dados_nao_compartilhados" \
        "$pilha_media" \
        "$texto_compartilhado" \
        "$pagina_bytes" \
        "$page_faults_maiores" \
        "$page_faults_menores" \
        "$swaps" \
        "$trocas_contexto_voluntarias" \
        "$trocas_contexto_involuntarias" \
        "$leituras_sistema_arquivos" \
        "$escritas_sistema_arquivos" \
        "$status_saida" \
        "$versao" \
        "$quantidade_threads" \
        "$oversubscription" \
        "$linhas_min_worker" \
        "$linhas_max_worker" \
        >> "$arquivo_execucoes"
}

validar_inteiro_positivo REPETICOES "$repeticoes"

read -r -a quantidades_threads <<< "$threads_lista"

if ((${#quantidades_threads[@]} == 0)); then
    printf 'THREADS_LISTA deve informar ao menos um valor.\n' >&2
    exit 1
fi

declare -A threads_informadas=()

for quantidade_threads in "${quantidades_threads[@]}"; do
    validar_inteiro_positivo THREADS_LISTA "$quantidade_threads"

    if [[ -n "${threads_informadas[$quantidade_threads]:-}" ]]; then
        printf 'THREADS_LISTA não pode conter valores repetidos.\n' >&2
        exit 1
    fi

    threads_informadas[$quantidade_threads]=1
done

for binario in "$binario_sequencial" "$binario_paralelo"; do
    if [[ ! -x "$binario" ]]; then
        printf 'Executável não encontrado em %s.\n' "$binario" >&2
        exit 1
    fi
done

shopt -s nullglob
arquivos_entrada=(
    "$diretorio_entradas/classicos/"*.txt
    "$diretorio_entradas/aleatorias/"*.txt
    "$diretorio_entradas/desempenho/"*.txt
)
shopt -u nullglob

if ((${#arquivos_entrada[@]} == 0)); then
    printf 'Nenhuma entrada predefinida foi encontrada.\n' >&2
    exit 1
fi

mkdir -p "$diretorio_resultados"

{
    printf 'inicio_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'inicio_epoch=%s\n' "$inicio_epoch"
    printf 'threads_lista=%s\n' "$threads_lista"
    printf 'repeticoes=%s\n' "$repeticoes"
    printf 'processadores_logicos_disponiveis=%s\n' "$processadores_logicos"
    printf 'cpus_permitidas=%s\n' "$(awk '/Cpus_allowed_list/ { print $2 }' /proc/self/status)"
    printf 'carga_media_inicial=%s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
    printf 'modelo_cpu=%s\n' "$(awk -F: '/model name/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }' /proc/cpuinfo)"
    printf 'memoria_total_kb=%s\n' "$(awk '/MemTotal/ { print $2 }' /proc/meminfo)"
    printf 'compilador=%s\n' "$(gcc --version | sed -n '1p')"
    printf 'sistema=%s\n' "$(uname -srmo)"

    if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
        printf 'repositorio=%s\n' "${GITHUB_REPOSITORY:-indisponivel}"
        printf 'commit=%s\n' "${GITHUB_SHA:-indisponivel}"
        printf 'execucao_actions=%s\n' "${GITHUB_RUN_ID:-indisponivel}"
        printf 'tentativa_actions=%s\n' "${GITHUB_RUN_ATTEMPT:-indisponivel}"
        printf 'runner=%s\n' "${RUNNER_NAME:-indisponivel}"
    fi

    printf '\n[topologia_cpu]\n'
    lscpu
} > "$arquivo_ambiente"

printf '%s\n' \
    'entrada,categoria,linhas,colunas,geracoes,rodada,celulas_vivas_iniciais,arquivo_entrada_bytes,memoria_matrizes_bytes,tempo_simulacao_segundos,tempo_usuario_segundos,tempo_sistema_segundos,tempo_parede_segundos,cpu_percentual,rss_maximo_kb,rss_medio_kb,memoria_total_media_kb,dados_nao_compartilhados_kb,pilha_media_kb,texto_compartilhado_kb,pagina_bytes,page_faults_maiores,page_faults_menores,swaps,trocas_contexto_voluntarias,trocas_contexto_involuntarias,leituras_sistema_arquivos,escritas_sistema_arquivos,status_saida,versao,threads,oversubscription,linhas_min_worker,linhas_max_worker' \
    > "$arquivo_execucoes"

total_execucoes=0

for arquivo_entrada in "${arquivos_entrada[@]}"; do
    linhas="$(sed -n '2s/[[:space:]].*//p' "$arquivo_entrada")"
    execucoes_por_rodada=1

    for quantidade_threads in "${quantidades_threads[@]}"; do
        if ((quantidade_threads <= linhas)); then
            ((execucoes_por_rodada += 1))
        fi
    done

    ((total_execucoes += execucoes_por_rodada * repeticoes))
done

printf 'Experimentos planejados: %d\n' "$total_execucoes"
printf 'Entradas: %d | Repetições: %d | Threads: %s\n' \
    "${#arquivos_entrada[@]}" \
    "$repeticoes" \
    "$threads_lista"

for arquivo_entrada in "${arquivos_entrada[@]}"; do
    entrada_relativa="${arquivo_entrada#"$diretorio_entradas/"}"
    categoria="$(basename "$(dirname "$arquivo_entrada")")"
    geracoes="$(sed -n '1p' "$arquivo_entrada")"
    read -r linhas colunas < <(sed -n '2p' "$arquivo_entrada")
    quantidade_vivas="$(sed -n '3p' "$arquivo_entrada")"
    tamanho_arquivo="$(stat -c '%s' "$arquivo_entrada")"
    memoria_matrizes=$((linhas * colunas * 2))

    validar_cabecalho \
        "$entrada_relativa" \
        "$geracoes" \
        "$linhas" \
        "$colunas" \
        "$quantidade_vivas"

    configuracoes=(sequencial:1)

    for quantidade_threads in "${quantidades_threads[@]}"; do
        if ((quantidade_threads <= linhas)); then
            configuracoes+=("paralelo:$quantidade_threads")
        fi
    done

    for ((rodada = 1; rodada <= repeticoes; rodada++)); do
        for ((posicao = 0; posicao < ${#configuracoes[@]}; posicao++)); do
            indice_configuracao="$posicao"

            if ((rodada % 2 == 0)); then
                indice_configuracao=$((${#configuracoes[@]} - posicao - 1))
            fi

            IFS=: read -r versao quantidade_threads \
                <<< "${configuracoes[$indice_configuracao]}"

            registrar_execucao \
                "$entrada_relativa" \
                "$categoria" \
                "$linhas" \
                "$colunas" \
                "$geracoes" \
                "$quantidade_vivas" \
                "$versao" \
                "$quantidade_threads" \
                "$rodada" \
                "$arquivo_entrada" \
                "$tamanho_arquivo" \
                "$memoria_matrizes"
        done
    done
done

{
    printf '%s\n' \
        'entrada,categoria,linhas,colunas,geracoes,threads,repeticoes,media_sequencial_segundos,desvio_sequencial_segundos,minimo_sequencial_segundos,maximo_sequencial_segundos,media_paralela_segundos,desvio_paralelo_segundos,minimo_paralelo_segundos,maximo_paralelo_segundos,speedup,eficiencia,eficiencia_percentual,cpu_paralela_media_percentual,nucleos_cpu_medios,rss_maximo_paralelo_medio_mib,custo_paralelo_segundos,sobrecusto_segundos,oversubscription,linhas_min_worker,linhas_max_worker'

    awk -F, '
        NR > 1 && $30 == "sequencial" {
            soma_sequencial[$1] += $10
            soma_quadrados_sequencial[$1] += $10 * $10
            quantidade_sequencial[$1]++
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
                media_sequencial = soma_sequencial[entrada] / quantidade_sequencial[entrada]
                media_paralela = soma_paralela[chave] / quantidade_paralela[chave]
                variancia_sequencial = quantidade_sequencial[entrada] > 1 \
                    ? (soma_quadrados_sequencial[entrada] - quantidade_sequencial[entrada] * media_sequencial * media_sequencial) / (quantidade_sequencial[entrada] - 1) \
                    : 0
                variancia_paralela = quantidade_paralela[chave] > 1 \
                    ? (soma_quadrados_paralela[chave] - quantidade_paralela[chave] * media_paralela * media_paralela) / (quantidade_paralela[chave] - 1) \
                    : 0
                desvio_sequencial = variancia_sequencial > 0 ? sqrt(variancia_sequencial) : 0
                desvio_paralelo = variancia_paralela > 0 ? sqrt(variancia_paralela) : 0
                speedup = media_paralela > 0 ? media_sequencial / media_paralela : 0
                eficiencia = threads > 0 ? speedup / threads : 0
                cpu_media = soma_cpu_paralela[chave] / quantidade_paralela[chave]
                rss_medio_mib = soma_rss_paralela[chave] / quantidade_paralela[chave] / 1024
                custo_paralelo = threads * media_paralela
                sobrecusto = custo_paralelo - media_sequencial

                printf "%s,%s,%d,%d,%d,%d,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.6f,%.6f,%.2f,%.3f,%.3f,%.3f,%.9f,%.9f,%s,%d,%d\n", \
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
                    linhas_max_worker[chave]
            }
        }
    ' "$arquivo_execucoes" | sort -t, -k1,1 -k6,6n
} > "$arquivo_resumo"

{
    printf '\nfim_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'fim_epoch=%s\n' "$(date +%s)"
    printf 'carga_media_final=%s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
} >> "$arquivo_ambiente"

printf '%s\n' \
    'Experimentos completos finalizados.' \
    "Execuções: $arquivo_execucoes" \
    "Resumo: $arquivo_resumo" \
    "Ambiente: $arquivo_ambiente"
