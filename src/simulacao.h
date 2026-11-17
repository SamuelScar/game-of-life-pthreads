#ifndef SIMULACAO_H
#define SIMULACAO_H

#include <stdbool.h>
#include <stddef.h>

typedef struct {
    int geracoes;
    int linhas;
    int colunas;
    bool *celulas;
} Mundo;

static size_t obter_indice(const Mundo *mundo, int linha, int coluna)
{
    return (size_t)linha * (size_t)mundo->colunas + (size_t)coluna;
}

static int contar_vizinhas(
    const Mundo *mundo,
    const bool *celulas,
    int linha,
    int coluna
)
{
    int quantidade = 0;

    for (int deslocamento_linha = -1;
         deslocamento_linha <= 1;
         deslocamento_linha++) {
        for (int deslocamento_coluna = -1;
             deslocamento_coluna <= 1;
             deslocamento_coluna++) {
            if (deslocamento_linha == 0 && deslocamento_coluna == 0)
                continue;

            const int linha_vizinha = linha + deslocamento_linha;
            const int coluna_vizinha = coluna + deslocamento_coluna;

            if (linha_vizinha < 0
                || linha_vizinha >= mundo->linhas
                || coluna_vizinha < 0
                || coluna_vizinha >= mundo->colunas) {
                continue;
            }

            quantidade += celulas[
                obter_indice(mundo, linha_vizinha, coluna_vizinha)
            ];
        }
    }

    return quantidade;
}

static bool calcular_estado(bool esta_viva, int quantidade_vizinhas)
{
    return quantidade_vizinhas == 3
        || (esta_viva && quantidade_vizinhas == 2);
}

static void evoluir_intervalo(
    const Mundo *mundo,
    const bool *geracao_atual,
    bool *proxima_geracao,
    int linha_inicial,
    int linha_final
)
{
    for (int linha = linha_inicial; linha < linha_final; linha++) {
        for (int coluna = 0; coluna < mundo->colunas; coluna++) {
            const size_t indice = obter_indice(mundo, linha, coluna);
            const int quantidade_vizinhas = contar_vizinhas(
                mundo,
                geracao_atual,
                linha,
                coluna
            );

            proxima_geracao[indice] = calcular_estado(
                geracao_atual[indice],
                quantidade_vizinhas
            );
        }
    }
}

#endif
