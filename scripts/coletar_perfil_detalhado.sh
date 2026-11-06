#!/usr/bin/env bash

set -euo pipefail

diretorio_script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
raiz_projeto="$(cd -- "$diretorio_script/.." && pwd)"
binario="$raiz_projeto/bin/sequencial"
entrada="${ENTRADA_PERFIL:-$raiz_projeto/entradas/aleatorias/quadrada-256x256-d10-s602.txt}"
diretorio_saida="$raiz_projeto/resultados/perfil"

if [[ ! -x "$binario" ]]; then
    printf 'Executável sequencial não encontrado em %s.\n' "$binario" >&2
    exit 1
fi

if [[ ! -f "$entrada" ]]; then
    printf 'Entrada de profiling não encontrada em %s.\n' "$entrada" >&2
    exit 1
fi

mkdir -p "$diretorio_saida"

printf '%s\n' "${entrada#"$raiz_projeto/"}" > "$diretorio_saida/entrada.txt"
cp /proc/meminfo "$diretorio_saida/meminfo-inicio.txt"
cp /proc/vmstat "$diretorio_saida/vmstat-inicio.txt"
lscpu > "$diretorio_saida/lscpu.txt"
objdump -d -Mintel "$binario" > "$diretorio_saida/sequencial-assembly.txt"

printf '%s\n' \
    'indice,nivel,tipo,tamanho,linha_bytes,conjuntos,vias,cpus_compartilhadas' \
    > "$diretorio_saida/caches.csv"

for diretorio_cache in /sys/devices/system/cpu/cpu0/cache/index*; do
    indice="$(basename "$diretorio_cache")"
    nivel="$(< "$diretorio_cache/level")"
    tipo="$(< "$diretorio_cache/type")"
    tamanho="$(< "$diretorio_cache/size")"
    linha_bytes="$(< "$diretorio_cache/coherency_line_size")"
    conjuntos="$(< "$diretorio_cache/number_of_sets")"
    vias="$(< "$diretorio_cache/ways_of_associativity")"
    cpus_compartilhadas="$(< "$diretorio_cache/shared_cpu_list")"

    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$indice" \
        "$nivel" \
        "$tipo" \
        "$tamanho" \
        "$linha_bytes" \
        "$conjuntos" \
        "$vias" \
        "$cpus_compartilhadas" \
        >> "$diretorio_saida/caches.csv"
done

OMITIR_SAIDA=1 valgrind \
    --tool=cachegrind \
    --branch-sim=yes \
    --cachegrind-out-file="$diretorio_saida/cachegrind.out" \
    --log-file="$diretorio_saida/cachegrind.log" \
    --error-exitcode=1 \
    "$binario" "$entrada"

cg_annotate \
    --auto=yes \
    "$diretorio_saida/cachegrind.out" \
    > "$diretorio_saida/cachegrind-resumo.txt"

OMITIR_SAIDA=1 valgrind \
    --tool=massif \
    --stacks=yes \
    --time-unit=B \
    --massif-out-file="$diretorio_saida/massif.out" \
    --log-file="$diretorio_saida/massif.log" \
    --error-exitcode=1 \
    "$binario" "$entrada"

ms_print "$diretorio_saida/massif.out" > "$diretorio_saida/massif-resumo.txt"

cp /proc/meminfo "$diretorio_saida/meminfo-fim.txt"
cp /proc/vmstat "$diretorio_saida/vmstat-fim.txt"

printf 'Perfil detalhado gerado em %s usando %s.\n' \
    "$diretorio_saida" \
    "${entrada#"$raiz_projeto/"}"
