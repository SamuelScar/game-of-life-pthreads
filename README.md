# game-of-life-pthreads

Implementações sequencial e paralela do Jogo da Vida de Conway em C. A versão
sequencial calcula as gerações em uma única thread. A versão paralela utilizará
Pthreads, decomposição de domínio e sincronização por barreiras.

Atualmente, o projeto contém a infraestrutura base e a implementação
sequencial. A versão paralela será adicionada na próxima etapa.

## Requisitos

- Docker
- Docker Compose

## Preparação do ambiente

Construa a imagem de desenvolvimento:

```bash
docker compose build
```

Os arquivos do repositório são montados em `/workspace` no container. Assim,
alterações feitas localmente ficam disponíveis imediatamente no ambiente.

Para abrir um terminal no container:

```bash
docker compose run --rm dev
```

## Compilação

Compile a versão sequencial com:

```bash
docker compose run --rm dev make
```

O executável será gerado na pasta `bin/`.

## Formato da entrada

O arquivo de entrada deve seguir este formato:

```text
N_GEN
L C
N
X1 Y1
X2 Y2
...
XN YN
```

- `N_GEN`: quantidade de gerações;
- `L C`: quantidade de linhas e colunas da matriz;
- `N`: quantidade inicial de células vivas;
- `X Y`: linha e coluna de uma célula viva.

As coordenadas começam em zero. Células fora dos limites da matriz são
consideradas mortas. Coordenadas repetidas ou fora da matriz tornam a entrada
inválida.

## Execução

Execute a versão sequencial informando o arquivo de entrada:

```bash
docker compose run --rm dev make run-sequential INPUT=entradas/exemplo.txt
```

O estado final é escrito na saída padrão no mesmo formato da entrada. A
quantidade de células vivas e as coordenadas correspondem à última geração.

O comando da versão paralela será:

```bash
docker compose run --rm dev make run INPUT=entradas/exemplo.txt THREADS=4
```

## Experimentos sequenciais

A série padrão executa matrizes quadradas de lados 128, 256, 512 e 1024, com
100 gerações, densidade inicial de 25% e cinco repetições por tamanho. Execute
com:

```bash
docker compose run --rm dev make experiments
```

Os parâmetros podem ser personalizados:

```bash
docker compose run --rm \
  -e TAMANHOS="256 512" \
  -e GERACOES=200 \
  -e DENSIDADE=30 \
  -e REPETICOES=3 \
  dev make experiments
```

As entradas são geradas de forma determinística e utilizam a semente 42 por
padrão. Cada série gera:

- `resultados/sequencial/execucoes.csv`, com todas as medições;
- `resultados/entradas/`, com os arquivos usados na série;
- `resultados/resumo_execucao.md`, com ambiente, médias, desvios-padrão,
  mínimos e máximos.

O workflow `Experimentos sequenciais` é iniciado manualmente no GitHub Actions.
Por padrão, ele executa uma série mais completa que a rotina local:

- matrizes quadradas de lados 64, 128, 256, 512, 1024 e 2048;
- 200 gerações por execução;
- densidade inicial de 25%;
- 10 repetições por tamanho, totalizando 60 medições;
- semente 42 para manter as entradas reproduzíveis.

O relatório é publicado no resumo da execução e os resultados são armazenados
como artefato por 30 dias. Ele apresenta média, desvio-padrão amostral, mínimo e
máximo de cada configuração.

A densidade, a quantidade de gerações e a semente permanecem fixas para que a
comparação isole o efeito do tamanho da matriz. Quando a implementação Pthreads
for adicionada, a série também variará o número de threads e calculará speedup e
eficiência usando a média sequencial do mesmo tamanho como referência.

Os tempos incluem somente a simulação das gerações. A leitura do arquivo e a
escrita do estado final ficam fora da medição. Speedup e eficiência serão
adicionados quando a versão paralela estiver disponível.

## Perfil de desempenho

Gere o perfil da versão sequencial com `gprof`:

```bash
docker compose run --rm dev make profile INPUT=entradas/exemplo.txt
```

## Limpeza

Remova os binários e os dados gerados pelo profiling:

```bash
docker compose run --rm dev make clean
```
