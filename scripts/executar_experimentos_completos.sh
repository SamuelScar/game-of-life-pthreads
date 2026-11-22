#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario_sequencial="$raiz_projeto/bin/sequencial"
binario_paralelo="$raiz_projeto/bin/paralelo"
binario_condicionador_cache="$raiz_projeto/bin/condicionar-cache"
processador_resultados="$diretorio_script/processar_resultados_experimentos.sh"
validador_processamento="$diretorio_script/validar_processamento_resultados.sh"
diretorio_entradas="$raiz_projeto/entradas"
diretorio_resultados="$raiz_projeto/resultados/experimentos_completos"
arquivo_execucoes="$diretorio_resultados/execucoes.csv"
arquivo_resumo="$diretorio_resultados/resumo_desempenho.csv"
arquivo_ambiente="$diretorio_resultados/ambiente_execucao.txt"
diretorio_temporario="$(mktemp -d)"
processadores_logicos="$(nproc)"
processadores_fisicos="$(lscpu -p=CORE,SOCKET | awk -F, '!/^#/ { seen[$1 SUBSEP $2]=1 } END { print length(seen) }')"
inicio_epoch="$(date +%s)"
numero_execucao=0
execucao_anterior=nenhuma

source "$diretorio_script/suporte_experimentos.sh"

trap 'rm -rf "$diretorio_temporario"' EXIT

repeticoes="${REPETICOES:-5}"
threads_lista="${THREADS_LISTA:-1 2 4 8}"
bytes_condicionamento_cache="$(obter_bytes_condicionamento_cache)"
cache_condicionada=nao

if ((bytes_condicionamento_cache > 0)); then
    cache_condicionada=sim
fi

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
    local posicao_configuracao="${13}"
    local execucao_precedente="${14}"
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
    local linhas_min_participante=0
    local linhas_max_participante=0
    local -a comando

    arquivo_erro="$diretorio_temporario/erro-${numero_execucao}.txt"
    arquivo_metricas="$diretorio_temporario/metricas-${numero_execucao}.csv"

    if [[ "$versao" == "sequencial" ]]; then
        comando=("$binario_sequencial" "$arquivo_entrada")
    else
        comando=("$binario_paralelo" "$arquivo_entrada" "$quantidade_threads")
        linhas_min_participante=$((linhas / quantidade_threads))
        linhas_max_participante=$(((linhas + quantidade_threads - 1) / quantidade_threads))

        if ((quantidade_threads > processadores_fisicos)); then
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

    if ! condicionar_cache_antes_medicao \
        "$binario_condicionador_cache" \
        "$bytes_condicionamento_cache"; then
        printf 'Não foi possível condicionar a cache antes da medição.\n' >&2
        exit 1
    fi

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

    if [[ "$status_saida" != "0" ]]; then
        printf 'Status de saída inválido para %s, versão %s, com %s thread(s).\n' \
            "$entrada_relativa" \
            "$versao" \
            "$quantidade_threads" \
            >&2
        exit 1
    fi

    printf '%s,%s,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%s,%d,%d,%d,%d,%s,%s,%d\n' \
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
        "$linhas_min_participante" \
        "$linhas_max_participante" \
        "$numero_execucao" \
        "$posicao_configuracao" \
        "$execucao_precedente" \
        "$cache_condicionada" \
        "$bytes_condicionamento_cache" \
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

if [[ -z "${threads_informadas[1]:-}" ]]; then
    printf 'THREADS_LISTA deve incluir 1 para calcular a escalabilidade relativa.\n' >&2
    exit 1
fi

for binario in "$binario_sequencial" "$binario_paralelo"; do
    if [[ ! -x "$binario" ]]; then
        printf 'Executável não encontrado em %s.\n' "$binario" >&2
        exit 1
    fi
done

if [[ ! -f "$processador_resultados" ]]; then
    printf 'Processador de resultados não encontrado em %s.\n' \
        "$processador_resultados" \
        >&2
    exit 1
fi

if [[ ! -f "$validador_processamento" ]]; then
    printf 'Validador do processamento não encontrado em %s.\n' \
        "$validador_processamento" \
        >&2
    exit 1
fi

bash "$validador_processamento"

if ((bytes_condicionamento_cache > 0)) \
    && [[ ! -x "$binario_condicionador_cache" ]]; then
    printf 'Condicionador de cache não encontrado em %s.\n' \
        "$binario_condicionador_cache" \
        >&2
    exit 1
fi

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
    printf 'thread_principal_participa=sim\n'
    printf 'semantica_quantidade_threads=total_participantes\n'
    printf 'repeticoes=%s\n' "$repeticoes"
    printf 'cache_condicionada=%s\n' "$cache_condicionada"
    printf 'cache_condicionamento_bytes=%d\n' "$bytes_condicionamento_cache"
    printf 'ordem_configuracoes=rotacao_balanceada\n'
    printf 'processadores_fisicos_disponiveis=%s\n' "$processadores_fisicos"
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
    'entrada,categoria,linhas,colunas,geracoes,rodada,celulas_vivas_iniciais,arquivo_entrada_bytes,memoria_matrizes_bytes,tempo_simulacao_segundos,tempo_usuario_segundos,tempo_sistema_segundos,tempo_parede_segundos,cpu_percentual,rss_maximo_kb,rss_medio_kb,memoria_total_media_kb,dados_nao_compartilhados_kb,pilha_media_kb,texto_compartilhado_kb,pagina_bytes,page_faults_maiores,page_faults_menores,swaps,trocas_contexto_voluntarias,trocas_contexto_involuntarias,leituras_sistema_arquivos,escritas_sistema_arquivos,status_saida,versao,threads,oversubscription,linhas_min_participante,linhas_max_participante,ordem_execucao,posicao_configuracao,execucao_anterior,cache_condicionada,cache_condicionamento_bytes' \
    > "$arquivo_execucoes"

total_execucoes=0
total_resumos_esperados=0

for arquivo_entrada in "${arquivos_entrada[@]}"; do
    linhas="$(sed -n '2s/[[:space:]].*//p' "$arquivo_entrada")"
    execucoes_por_rodada=1

    for quantidade_threads in "${quantidades_threads[@]}"; do
        if ((quantidade_threads <= linhas)); then
            ((execucoes_por_rodada += 1))
            ((total_resumos_esperados += 1))
        fi
    done

    ((total_execucoes += execucoes_por_rodada * repeticoes))
done

printf 'Experimentos planejados: %d\n' "$total_execucoes"
printf 'Entradas: %d | Repetições: %d | Threads: %s\n' \
    "${#arquivos_entrada[@]}" \
    "$repeticoes" \
    "$threads_lista"

for ((rodada = 1; rodada <= repeticoes; rodada++)); do
    quantidade_entradas="${#arquivos_entrada[@]}"
    deslocamento_entrada=$(((rodada - 1) % quantidade_entradas))

    for ((posicao_entrada = 0;
         posicao_entrada < quantidade_entradas;
         posicao_entrada++)); do
        if ((rodada % 2 == 1)); then
            indice_entrada=$(((posicao_entrada + deslocamento_entrada) % quantidade_entradas))
        else
            indice_entrada=$(((deslocamento_entrada - posicao_entrada + quantidade_entradas) % quantidade_entradas))
        fi

        arquivo_entrada="${arquivos_entrada[$indice_entrada]}"
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

        quantidade_configuracoes="${#configuracoes[@]}"
        deslocamento_configuracao=$(((rodada + indice_entrada - 1) % quantidade_configuracoes))
        ciclo_configuracao=$(((rodada - 1) / quantidade_configuracoes))

        for ((posicao = 0; posicao < quantidade_configuracoes; posicao++)); do
            if ((ciclo_configuracao % 2 == 0)); then
                indice_configuracao=$(((posicao + deslocamento_configuracao) % quantidade_configuracoes))
            else
                indice_configuracao=$(((deslocamento_configuracao - posicao + quantidade_configuracoes) % quantidade_configuracoes))
            fi

            IFS=: read -r versao quantidade_threads \
                <<< "${configuracoes[$indice_configuracao]}"

            ((numero_execucao += 1))

            posicao_configuracao=$((posicao + 1))

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
                "$memoria_matrizes" \
                "$posicao_configuracao" \
                "$execucao_anterior"

            execucao_anterior="${entrada_relativa}:${versao}:${quantidade_threads}"
        done
    done
done

{
    printf '\nfim_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'fim_epoch=%s\n' "$(date +%s)"
    printf 'carga_media_final=%s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
} >> "$arquivo_ambiente"

REPETICOES="$repeticoes" bash "$processador_resultados" \
    "$diretorio_resultados" \
    "$total_execucoes" \
    "$total_resumos_esperados"

printf '%s\n' \
    'Experimentos completos finalizados.' \
    "Execuções: $arquivo_execucoes" \
    "Resumo: $arquivo_resumo" \
    "Ambiente: $arquivo_ambiente"
