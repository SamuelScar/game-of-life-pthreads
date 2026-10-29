#define _POSIX_C_SOURCE 200809L

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    int geracoes;
    int linhas;
    int colunas;
    bool *celulas;
} Mundo;

static bool opcao_ativa(const char *nome)
{
    const char *valor = getenv(nome);

    return valor != NULL && strcmp(valor, "1") == 0;
}

static double obter_tempo_atual(void)
{
    struct timespec tempo;

    clock_gettime(CLOCK_MONOTONIC, &tempo);
    return (double)tempo.tv_sec + (double)tempo.tv_nsec / 1e9;
}

static size_t obter_indice(const Mundo *mundo, int linha, int coluna)
{
    return (size_t)linha * (size_t)mundo->colunas + (size_t)coluna;
}

static bool dimensoes_validas(int linhas, int colunas)
{
    return linhas > 0
        && colunas > 0
        && (size_t)linhas <= SIZE_MAX / (size_t)colunas;
}

static bool ler_mundo(FILE *arquivo, Mundo *mundo)
{
    int quantidade_vivas;

    if (fscanf(arquivo, "%d", &mundo->geracoes) != 1
        || fscanf(arquivo, "%d %d", &mundo->linhas, &mundo->colunas) != 2
        || fscanf(arquivo, "%d", &quantidade_vivas) != 1
        || mundo->geracoes < 0
        || quantidade_vivas < 0
        || !dimensoes_validas(mundo->linhas, mundo->colunas)) {
        return false;
    }

    const size_t quantidade_celulas =
        (size_t)mundo->linhas * (size_t)mundo->colunas;

    if ((size_t)quantidade_vivas > quantidade_celulas)
        return false;

    mundo->celulas = calloc(quantidade_celulas, sizeof(*mundo->celulas));

    if (mundo->celulas == NULL)
        return false;

    for (int i = 0; i < quantidade_vivas; i++) {
        int linha;
        int coluna;

        if (fscanf(arquivo, "%d %d", &linha, &coluna) != 2
            || linha < 0
            || linha >= mundo->linhas
            || coluna < 0
            || coluna >= mundo->colunas) {
            return false;
        }

        const size_t indice = obter_indice(mundo, linha, coluna);

        if (mundo->celulas[indice])
            return false;

        mundo->celulas[indice] = true;
    }

    return true;
}

static int contar_vizinhas(const Mundo *mundo, int linha, int coluna)
{
    int quantidade = 0;

    for (int deslocamento_linha = -1; deslocamento_linha <= 1; deslocamento_linha++) {
        for (int deslocamento_coluna = -1; deslocamento_coluna <= 1; deslocamento_coluna++) {
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

            quantidade += mundo->celulas[
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

static int simular(Mundo *mundo)
{
    if (mundo->geracoes == 0)
        return EXIT_SUCCESS;

    const size_t quantidade_celulas =
        (size_t)mundo->linhas * (size_t)mundo->colunas;
    bool *proxima_geracao = malloc(
        quantidade_celulas * sizeof(*proxima_geracao)
    );

    if (proxima_geracao == NULL)
        return EXIT_FAILURE;

    for (int geracao = 0; geracao < mundo->geracoes; geracao++) {
        for (int linha = 0; linha < mundo->linhas; linha++) {
            for (int coluna = 0; coluna < mundo->colunas; coluna++) {
                const size_t indice = obter_indice(mundo, linha, coluna);
                const int quantidade_vizinhas = contar_vizinhas(
                    mundo,
                    linha,
                    coluna
                );

                proxima_geracao[indice] = calcular_estado(
                    mundo->celulas[indice],
                    quantidade_vizinhas
                );
            }
        }

        bool *geracao_anterior = mundo->celulas;
        mundo->celulas = proxima_geracao;
        proxima_geracao = geracao_anterior;
    }

    free(proxima_geracao);
    return EXIT_SUCCESS;
}

static size_t contar_celulas_vivas(const Mundo *mundo)
{
    const size_t quantidade_celulas =
        (size_t)mundo->linhas * (size_t)mundo->colunas;
    size_t quantidade_vivas = 0;

    for (size_t indice = 0; indice < quantidade_celulas; indice++)
        quantidade_vivas += mundo->celulas[indice];

    return quantidade_vivas;
}

static void escrever_mundo(const Mundo *mundo)
{
    printf("%d\n", mundo->geracoes);
    printf("%d %d\n", mundo->linhas, mundo->colunas);
    printf("%zu\n", contar_celulas_vivas(mundo));

    for (int linha = 0; linha < mundo->linhas; linha++) {
        for (int coluna = 0; coluna < mundo->colunas; coluna++) {
            if (mundo->celulas[obter_indice(mundo, linha, coluna)])
                printf("%d %d\n", linha, coluna);
        }
    }
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "Uso: %s <arquivo_de_entrada>\n", argv[0]);
        return EXIT_FAILURE;
    }

    FILE *arquivo = fopen(argv[1], "r");

    if (arquivo == NULL) {
        fprintf(stderr, "Nao foi possivel abrir o arquivo de entrada.\n");
        return EXIT_FAILURE;
    }

    Mundo mundo = {0};
    const bool entrada_valida = ler_mundo(arquivo, &mundo);
    fclose(arquivo);

    if (!entrada_valida) {
        free(mundo.celulas);
        fprintf(stderr, "Arquivo de entrada invalido.\n");
        return EXIT_FAILURE;
    }

    const double inicio_tempo = obter_tempo_atual();
    const int status_simulacao = simular(&mundo);
    const double tempo_simulacao = obter_tempo_atual() - inicio_tempo;

    if (status_simulacao != EXIT_SUCCESS) {
        free(mundo.celulas);
        fprintf(stderr, "Nao foi possivel alocar memoria para a simulacao.\n");
        return EXIT_FAILURE;
    }

    if (opcao_ativa("MEDIR_TEMPO"))
        fprintf(stderr, "tempo_segundos=%.9f\n", tempo_simulacao);

    if (!opcao_ativa("OMITIR_SAIDA"))
        escrever_mundo(&mundo);

    free(mundo.celulas);
    return EXIT_SUCCESS;
}
