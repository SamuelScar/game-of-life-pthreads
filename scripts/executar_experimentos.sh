#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario="$raiz_projeto/bin/sequencial"
diretorio_entradas="$raiz_projeto/entradas"
diretorio_resultados="$raiz_projeto/resultados"
arquivo_resultados="$diretorio_resultados/sequencial/execucoes.csv"
arquivo_inicio="$diretorio_resultados/inicio_execucao.txt"
diretorio_temporario="$(mktemp -d)"

trap 'rm -rf "$diretorio_temporario"' EXIT

repeticoes="${REPETICOES:-5}"

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

validar_inteiro_positivo REPETICOES "$repeticoes"

if [[ ! -x "$binario" ]]; then
    printf 'Executável sequencial não encontrado em %s.\n' "$binario" >&2
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

mkdir -p "$(dirname "$arquivo_resultados")"

printf '%s\n%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$(date +%s)" \
    > "$arquivo_inicio"

printf '%s\n' \
    'entrada,categoria,linhas,colunas,geracoes,rodada,celulas_vivas_iniciais,arquivo_entrada_bytes,memoria_matrizes_bytes,tempo_simulacao_segundos,tempo_usuario_segundos,tempo_sistema_segundos,tempo_parede_segundos,cpu_percentual,rss_maximo_kb,rss_medio_kb,memoria_total_media_kb,dados_nao_compartilhados_kb,pilha_media_kb,texto_compartilhado_kb,pagina_bytes,page_faults_maiores,page_faults_menores,swaps,trocas_contexto_voluntarias,trocas_contexto_involuntarias,leituras_sistema_arquivos,escritas_sistema_arquivos,status_saida' \
    > "$arquivo_resultados"

total_execucoes=$((${#arquivos_entrada[@]} * repeticoes))
printf 'Experimentos sequenciais planejados: %d\n' "$total_execucoes"
printf 'Entradas predefinidas: %d | Repetições: %d\n' \
    "${#arquivos_entrada[@]}" \
    "$repeticoes"

for ((rodada = 1; rodada <= repeticoes; rodada++)); do
    for indice in "${!arquivos_entrada[@]}"; do
        arquivo_entrada="${arquivos_entrada[$indice]}"
        entrada_relativa="${arquivo_entrada#"$diretorio_entradas/"}"
        categoria="$(basename "$(dirname "$arquivo_entrada")")"
        geracoes="$(sed -n '1p' "$arquivo_entrada")"
        read -r linhas colunas < <(sed -n '2p' "$arquivo_entrada")
        quantidade_vivas="$(sed -n '3p' "$arquivo_entrada")"

        validar_cabecalho \
            "$entrada_relativa" \
            "$geracoes" \
            "$linhas" \
            "$colunas" \
            "$quantidade_vivas"

        tamanho_arquivo="$(stat -c '%s' "$arquivo_entrada")"
        memoria_matrizes=$((linhas * colunas * 2))

        arquivo_erro="$diretorio_temporario/erro-${indice}-${rodada}.txt"
        arquivo_metricas="$diretorio_temporario/metricas-${indice}-${rodada}.csv"
        printf 'Sequencial | Entrada=%s | Matriz=%dx%d | Gerações=%d | Rodada=%d/%d\n' \
            "$entrada_relativa" \
            "$linhas" \
            "$colunas" \
            "$geracoes" \
            "$rodada" \
            "$repeticoes"

        if ! /usr/bin/time \
            --output="$arquivo_metricas" \
            --format='%U,%S,%e,%P,%M,%t,%K,%D,%p,%X,%Z,%F,%R,%W,%w,%c,%I,%O,%x' \
            env MEDIR_TEMPO=1 OMITIR_SAIDA=1 \
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

        printf '%s,%s,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
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
            >> "$arquivo_resultados"
    done
done

STATUS_EXECUCAO=sucesso bash "$diretorio_script/gerar_relatorio.sh"

printf '%s\n' \
    'Experimentos sequenciais finalizados.' \
    "Resultados: $arquivo_resultados" \
    "Relatório: $diretorio_resultados/resumo_execucao.md"
