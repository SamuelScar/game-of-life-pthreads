#!/usr/bin/env bash

converter_tamanho_cache_para_bytes()
{
    local tamanho="${1^^}"
    local multiplicador=1
    local valor

    if [[ "$tamanho" =~ ^([0-9]+)([KMG])?$ ]]; then
        valor="${BASH_REMATCH[1]}"

        case "${BASH_REMATCH[2]:-}" in
            K) multiplicador=1024 ;;
            M) multiplicador=$((1024 * 1024)) ;;
            G) multiplicador=$((1024 * 1024 * 1024)) ;;
        esac

        printf '%d\n' "$((valor * multiplicador))"
        return 0
    fi

    return 1
}

detectar_maior_cache_dados_bytes()
{
    local diretorio_cache
    local tamanho
    local tamanho_bytes
    local tipo
    local maior_tamanho=0

    for diretorio_cache in /sys/devices/system/cpu/cpu0/cache/index*; do
        if [[ ! -r "$diretorio_cache/type"
            || ! -r "$diretorio_cache/size" ]]; then
            continue
        fi

        tipo="$(< "$diretorio_cache/type")"

        if [[ "$tipo" != "Data" && "$tipo" != "Unified" ]]; then
            continue
        fi

        tamanho="$(< "$diretorio_cache/size")"

        if ! tamanho_bytes="$(converter_tamanho_cache_para_bytes "$tamanho")"; then
            continue
        fi

        if ((tamanho_bytes > maior_tamanho)); then
            maior_tamanho="$tamanho_bytes"
        fi
    done

    printf '%d\n' "$maior_tamanho"
}

obter_bytes_condicionamento_cache()
{
    local habilitado="${CONDICIONAR_CACHE:-1}"
    local valor_informado="${BYTES_CONDICIONAMENTO_CACHE:-}"
    local maior_cache
    local quantidade_bytes
    local minimo=$((64 * 1024 * 1024))
    local maximo=$((512 * 1024 * 1024))

    if [[ "$habilitado" != "0" && "$habilitado" != "1" ]]; then
        printf 'CONDICIONAR_CACHE deve ser 0 ou 1.\n' >&2
        return 1
    fi

    if [[ "$habilitado" == "0" ]]; then
        printf '0\n'
        return 0
    fi

    if [[ -n "$valor_informado" ]]; then
        if [[ ! "$valor_informado" =~ ^[1-9][0-9]*$ ]]; then
            printf 'BYTES_CONDICIONAMENTO_CACHE deve ser um inteiro positivo.\n' >&2
            return 1
        fi

        printf '%s\n' "$valor_informado"
        return 0
    fi

    maior_cache="$(detectar_maior_cache_dados_bytes)"

    if ((maior_cache == 0)); then
        quantidade_bytes="$minimo"
    else
        quantidade_bytes=$((maior_cache * 4))
    fi

    if ((quantidade_bytes < minimo)); then
        quantidade_bytes="$minimo"
    elif ((quantidade_bytes > maximo)); then
        quantidade_bytes="$maximo"
    fi

    printf '%d\n' "$quantidade_bytes"
}

condicionar_cache_antes_medicao()
{
    local binario="$1"
    local quantidade_bytes="$2"

    if ((quantidade_bytes == 0)); then
        return 0
    fi

    "$binario" "$quantidade_bytes"
}
