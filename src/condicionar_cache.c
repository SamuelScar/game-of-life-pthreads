#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int ler_quantidade_bytes(const char *texto, size_t *quantidade_bytes)
{
    char *fim;

    errno = 0;
    const unsigned long long valor = strtoull(texto, &fim, 10);

    if (errno != 0
        || fim == texto
        || *fim != '\0'
        || valor == 0
        || valor > SIZE_MAX) {
        return EXIT_FAILURE;
    }

    *quantidade_bytes = (size_t)valor;
    return EXIT_SUCCESS;
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "Uso: %s <quantidade_bytes>\n", argv[0]);
        return EXIT_FAILURE;
    }

    size_t quantidade_bytes;

    if (ler_quantidade_bytes(argv[1], &quantidade_bytes) != EXIT_SUCCESS) {
        fprintf(stderr, "Quantidade de bytes invalida.\n");
        return EXIT_FAILURE;
    }

    volatile unsigned char *buffer = malloc(quantidade_bytes);

    if (buffer == NULL) {
        fprintf(stderr, "Nao foi possivel alocar o buffer de cache.\n");
        return EXIT_FAILURE;
    }

    const size_t tamanho_linha_cache = 64;
    volatile unsigned long soma = 0;

    for (size_t indice = 0;
         indice < quantidade_bytes;
         indice += tamanho_linha_cache) {
        buffer[indice] = (unsigned char)(indice / tamanho_linha_cache);
    }

    for (size_t indice = 0;
         indice < quantidade_bytes;
         indice += tamanho_linha_cache) {
        soma += buffer[indice];
    }

    free((void *)buffer);
    (void)soma;
    return EXIT_SUCCESS;
}
