#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "simulacao.h"

typedef struct {
    Mundo *mundo;
    bool *proxima_geracao;
    pthread_barrier_t barreira;
    pthread_mutex_t mutex_inicio;
    pthread_cond_t condicao_inicio;
    bool inicio_liberado;
    bool cancelar;
    _Atomic bool erro_barreira;
} SimulacaoParalela;

typedef struct {
    SimulacaoParalela *simulacao;
    int linha_inicial;
    int linha_final;
} Worker;

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

static bool ler_quantidade_threads(const char *texto, int *quantidade_threads)
{
    char *fim;

    errno = 0;
    const long valor = strtol(texto, &fim, 10);

    if (errno != 0
        || fim == texto
        || *fim != '\0'
        || valor < 1
        || valor > INT_MAX) {
        return false;
    }

    *quantidade_threads = (int)valor;
    return true;
}

static bool aguardar_inicio(SimulacaoParalela *simulacao)
{
    pthread_mutex_lock(&simulacao->mutex_inicio);

    while (!simulacao->inicio_liberado)
        pthread_cond_wait(&simulacao->condicao_inicio, &simulacao->mutex_inicio);

    const bool executar = !simulacao->cancelar;
    pthread_mutex_unlock(&simulacao->mutex_inicio);

    return executar;
}

static void executar_geracoes(Worker *worker)
{
    SimulacaoParalela *simulacao = worker->simulacao;
    Mundo *mundo = simulacao->mundo;
    bool *geracao_atual = mundo->celulas;
    bool *proxima_geracao = simulacao->proxima_geracao;

    for (int geracao = 0; geracao < mundo->geracoes; geracao++) {
        evoluir_intervalo(
            mundo,
            geracao_atual,
            proxima_geracao,
            worker->linha_inicial,
            worker->linha_final
        );

        const int status_barreira = pthread_barrier_wait(&simulacao->barreira);

        if (status_barreira != 0
            && status_barreira != PTHREAD_BARRIER_SERIAL_THREAD) {
            atomic_store(&simulacao->erro_barreira, true);
            break;
        }

        if (atomic_load(&simulacao->erro_barreira))
            break;

        bool *geracao_anterior = geracao_atual;
        geracao_atual = proxima_geracao;
        proxima_geracao = geracao_anterior;
    }
}

static void *executar_worker(void *argumento)
{
    Worker *worker = argumento;

    if (aguardar_inicio(worker->simulacao))
        executar_geracoes(worker);

    return NULL;
}

static void definir_faixa(
    Worker *worker,
    int indice,
    int quantidade_threads,
    int quantidade_linhas
)
{
    const int linhas_base = quantidade_linhas / quantidade_threads;
    const int restante = quantidade_linhas % quantidade_threads;
    const int linhas_anteriores = indice * linhas_base
        + (indice < restante ? indice : restante);

    worker->linha_inicial = linhas_anteriores;
    worker->linha_final = linhas_anteriores
        + linhas_base
        + (indice < restante ? 1 : 0);
}

static bool inicializar_sincronizacao(
    SimulacaoParalela *simulacao,
    int quantidade_threads
)
{
    if (pthread_mutex_init(&simulacao->mutex_inicio, NULL) != 0)
        return false;

    if (pthread_cond_init(&simulacao->condicao_inicio, NULL) != 0) {
        pthread_mutex_destroy(&simulacao->mutex_inicio);
        return false;
    }

    if (pthread_barrier_init(
            &simulacao->barreira,
            NULL,
            (unsigned int)quantidade_threads
        ) != 0) {
        pthread_cond_destroy(&simulacao->condicao_inicio);
        pthread_mutex_destroy(&simulacao->mutex_inicio);
        return false;
    }

    return true;
}

static void destruir_sincronizacao(SimulacaoParalela *simulacao)
{
    pthread_barrier_destroy(&simulacao->barreira);
    pthread_cond_destroy(&simulacao->condicao_inicio);
    pthread_mutex_destroy(&simulacao->mutex_inicio);
}

static void liberar_workers(SimulacaoParalela *simulacao, bool cancelar)
{
    pthread_mutex_lock(&simulacao->mutex_inicio);
    simulacao->cancelar = cancelar;
    simulacao->inicio_liberado = true;
    pthread_cond_broadcast(&simulacao->condicao_inicio);
    pthread_mutex_unlock(&simulacao->mutex_inicio);
}

static int simular(Mundo *mundo, int quantidade_threads)
{
    if (mundo->geracoes == 0)
        return EXIT_SUCCESS;

    const size_t quantidade_celulas =
        (size_t)mundo->linhas * (size_t)mundo->colunas;
    bool *proxima_geracao = malloc(
        quantidade_celulas * sizeof(*proxima_geracao)
    );
    const int quantidade_threads_auxiliares = quantidade_threads - 1;
    pthread_t *threads = NULL;

    if (quantidade_threads_auxiliares > 0) {
        threads = calloc(
            (size_t)quantidade_threads_auxiliares,
            sizeof(*threads)
        );
    }

    Worker *workers = calloc(
        (size_t)quantidade_threads,
        sizeof(*workers)
    );

    if (proxima_geracao == NULL
        || workers == NULL
        || (quantidade_threads_auxiliares > 0 && threads == NULL)) {
        free(proxima_geracao);
        free(threads);
        free(workers);
        return EXIT_FAILURE;
    }

    SimulacaoParalela simulacao = {
        .mundo = mundo,
        .proxima_geracao = proxima_geracao,
        .erro_barreira = false
    };

    if (!inicializar_sincronizacao(&simulacao, quantidade_threads)) {
        free(proxima_geracao);
        free(threads);
        free(workers);
        return EXIT_FAILURE;
    }

    for (int indice = 0; indice < quantidade_threads; indice++) {
        workers[indice].simulacao = &simulacao;
        definir_faixa(
            &workers[indice],
            indice,
            quantidade_threads,
            mundo->linhas
        );
    }

    int threads_auxiliares_criadas = 0;

    for (int indice = 0;
         indice < quantidade_threads_auxiliares;
         indice++) {
        if (pthread_create(
                &threads[indice],
                NULL,
                executar_worker,
                &workers[indice]
            ) != 0) {
            break;
        }

        threads_auxiliares_criadas++;
    }

    const bool criacao_completa =
        threads_auxiliares_criadas == quantidade_threads_auxiliares;
    liberar_workers(&simulacao, !criacao_completa);

    const int indice_thread_principal = quantidade_threads - 1;

    if (criacao_completa)
        executar_geracoes(&workers[indice_thread_principal]);

    bool finalizacao_completa = true;

    for (int indice = 0;
         indice < threads_auxiliares_criadas;
         indice++) {
        if (pthread_join(threads[indice], NULL) != 0)
            finalizacao_completa = false;
    }

    destruir_sincronizacao(&simulacao);
    free(threads);
    free(workers);

    if (!criacao_completa
        || !finalizacao_completa
        || atomic_load(&simulacao.erro_barreira)) {
        free(proxima_geracao);
        return EXIT_FAILURE;
    }

    bool *geracao_inicial = mundo->celulas;

    if (mundo->geracoes % 2 == 0) {
        free(proxima_geracao);
    } else {
        mundo->celulas = proxima_geracao;
        free(geracao_inicial);
    }

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
    if (argc != 3) {
        fprintf(
            stderr,
            "Uso: %s <arquivo_de_entrada> <quantidade_threads>\n",
            argv[0]
        );
        return EXIT_FAILURE;
    }

    int quantidade_threads;

    if (!ler_quantidade_threads(argv[2], &quantidade_threads)) {
        fprintf(stderr, "Quantidade de threads invalida.\n");
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

    if (quantidade_threads > mundo.linhas) {
        free(mundo.celulas);
        fprintf(
            stderr,
            "A quantidade de threads nao pode exceder a quantidade de linhas.\n"
        );
        return EXIT_FAILURE;
    }

    const double inicio_tempo = obter_tempo_atual();
    const int status_simulacao = simular(&mundo, quantidade_threads);
    const double tempo_simulacao = obter_tempo_atual() - inicio_tempo;

    if (status_simulacao != EXIT_SUCCESS) {
        free(mundo.celulas);
        fprintf(stderr, "Nao foi possivel executar a simulacao paralela.\n");
        return EXIT_FAILURE;
    }

    if (opcao_ativa("MEDIR_TEMPO"))
        fprintf(stderr, "tempo_segundos=%.9f\n", tempo_simulacao);

    if (!opcao_ativa("OMITIR_SAIDA"))
        escrever_mundo(&mundo);

    free(mundo.celulas);
    return EXIT_SUCCESS;
}
