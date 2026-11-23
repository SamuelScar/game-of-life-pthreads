# game-of-life-pthreads

Implementações sequencial e paralela do Jogo da Vida de Conway em C. A versão
sequencial calcula as gerações em uma única thread. A versão paralela utiliza
Pthreads, decomposição horizontal do domínio e sincronização por barreiras. A
quantidade informada inclui a thread principal, que também processa uma faixa de
linhas.

## Requisitos

- GCC, Make e uma implementação de Pthreads; ou
- Docker com Docker Compose.

## Compilação e execução local

Compile as implementações diretamente com:

```bash
make
```

Execute a versão sequencial:

```bash
make run-sequential INPUT=entradas/exemplo.txt
```

Execute a versão paralela informando o total de participantes:

```bash
make run-parallel INPUT=entradas/exemplo.txt THREADS=4
```

## Execução com Docker

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

## Organização

- `src/sequencial.c`: implementação de referência;
- `src/paralelo.c`: implementação Pthreads;
- `src/simulacao.h`: representação e kernel comuns às duas versões;
- `src/condicionar_cache.c`: condicionamento controlado da cache entre medições;
- `scripts/suporte_experimentos.sh`: detecção e condicionamento da cache;
- `scripts/executar_experimentos_completos.sh`: comparação sequencial e paralela;
- `scripts/processar_resultados_experimentos.sh`: valida e consolida medições já coletadas;
- `scripts/coletar_perfil_sequencial.sh`: profiling detalhado da referência;
- `scripts/gerar_relatorio_experimentos.sh`: relatório Markdown das medições;
- `.github/workflows/experimentos-completos.yml`: automação da série completa;
- `docs/relatorio.tex`: fonte do relatório técnico.

### Compilação no container

Compile as duas versões com:

```bash
docker compose run --rm dev make
```

Os executáveis `sequencial` e `paralelo` serão gerados na pasta `bin/`. O
condicionador de cache é compilado automaticamente apenas quando a campanha de
experimentos é executada.

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

### Execução no container

Execute a versão sequencial informando o arquivo de entrada:

```bash
docker compose run --rm dev make run-sequential INPUT=entradas/exemplo.txt
```

O estado final é escrito na saída padrão no mesmo formato da entrada. A
quantidade de células vivas e as coordenadas correspondem à última geração.

Execute a versão paralela informando também a quantidade de threads:

```bash
docker compose run --rm dev make run-parallel \
  INPUT=entradas/exemplo.txt \
  THREADS=4
```

`THREADS` representa o total de participantes do cálculo. A thread principal
processa uma faixa e são criadas `THREADS - 1` threads auxiliares. Com
`THREADS=1`, a principal executa toda a simulação sem criar uma auxiliar.
O retorno da barreira é verificado a cada geração; um erro devolvido pela
biblioteca é registrado e faz a simulação terminar com falha depois que as
threads auxiliares são recolhidas.

## Entradas disponíveis

Além de `entradas/exemplo.txt`, o projeto contém entradas clássicas do Jogo da
Vida e estados pseudoaleatórios fixos. Como os estados aleatórios estão salvos
no repositório, a mesma entrada sempre produz o mesmo resultado.

### Padrões clássicos

| Entrada | Categoria | Comportamento esperado |
|---|---|---|
| `bloco.txt` | Estado estável | Permanece inalterado |
| `colmeia.txt` | Estado estável | Permanece inalterado |
| `loaf.txt` | Estado estável | Permanece inalterado |
| `barco.txt` | Estado estável | Permanece inalterado |
| `banheira.txt` | Estado estável | Permanece inalterado |
| `pisca-pisca.txt` | Oscilador | Alterna entre duas formas |
| `sapo.txt` | Oscilador | Alterna entre duas formas |
| `farol.txt` | Oscilador | Alterna entre duas formas |
| `pulsar.txt` | Oscilador | Retorna ao estado inicial após três gerações |
| `pentadecatlo.txt` | Oscilador | Retorna ao estado inicial após quinze gerações |
| `planador.txt` | Nave | Desloca-se diagonalmente |
| `nave-leve.txt` | Nave | Desloca-se horizontalmente |
| `nave-media.txt` | Nave | Desloca-se horizontalmente |
| `nave-pesada.txt` | Nave | Desloca-se horizontalmente |
| `r-pentomino.txt` | Matusalém | Evolui por muitas gerações |
| `diehard.txt` | Matusalém | Desaparece após aproximadamente 130 gerações |
| `acorn.txt` | Matusalém | Produz uma evolução longa e complexa |
| `canhao-gosper.txt` | Gerador | Produz planadores periodicamente |

Esses arquivos estão em `entradas/classicos/`.

### Estados pseudoaleatórios

O diretório `entradas/aleatorias/` contém 35 entradas produzidas por um gerador
pseudoaleatório. Elas combinam:

- matrizes quadradas pequenas de 5 × 5 e 10 × 10;
- matrizes quadradas intermediárias de 20 × 20, 40 × 40 e 80 × 80;
- matrizes quadradas grandes de 256 × 256 e 512 × 512;
- uma matriz quadrada muito grande de 1024 × 1024;
- matrizes retangulares entre 30 × 90 e 1024 × 256;
- densidades iniciais entre 1% e 75%;
- uma semente diferente para cada configuração.

As maiores matrizes usam densidades e quantidades de gerações menores para
limitar o tamanho dos arquivos e o tempo total dos experimentos.

As sementes fazem parte dos nomes dos arquivos. Isso mantém as posições
aleatórias reproduzíveis entre a versão sequencial, a versão paralela e as
execuções do GitHub Actions.

### Entradas de desempenho

O diretório `entradas/desempenho/` contém seis cargas maiores, separadas das
entradas pseudoaleatórias de uso geral. Elas combinam matrizes quadradas e
retangulares entre 1024 × 1024 e 8192 × 8192, com até 500 gerações. A maior
configuração utiliza aproximadamente 128 MiB nas duas matrizes da simulação.

Essas entradas foram dimensionadas para produzir execuções sequenciais com
duração suficiente para comparar speedup e eficiência da versão com Pthreads.
Com dez repetições, elas acrescentam aproximadamente 99,6 bilhões de
atualizações de célula às execuções sequenciais da campanha completa.

## Métricas e perfil

Cada execução da campanha completa registra no CSV:

- tempo interno da simulação;
- tempos de usuário, sistema e parede;
- percentual de CPU;
- RSS máximo e médio;
- memória média total, dados, pilha e texto compartilhado;
- tamanho das duas matrizes e do arquivo de entrada;
- tamanho da página de memória;
- page faults maiores e menores;
- quantidade de swaps;
- trocas de contexto voluntárias e involuntárias;
- leituras e escritas no sistema de arquivos;
- status de saída do processo.

O workflow também executa um profiling detalhado sobre
`entradas/aleatorias/quadrada-256x256-d10-s602.txt`. Essa etapa gera em
`resultados/perfil_sequencial/`:

- `cachegrind-resumo.txt`, com referências a instruções, leituras, escritas,
  faltas nos caches simulados e desvios de fluxo;
- `massif-resumo.txt`, com a evolução e o pico de heap e pilha;
- `caches.csv`, com níveis, tamanhos, linhas, conjuntos e associatividade dos
  caches do processador;
- `sequencial-assembly.txt`, para analisar instruções e uso de registradores;
- snapshots de `/proc/meminfo` e `/proc/vmstat` antes e depois do profiling;
- saídas brutas do Cachegrind e do Massif para análises posteriores.

O profiling detalhado pode ser executado localmente depois da compilação:

```bash
docker compose run --rm dev make profile-sequential-detailed
```

O Cachegrind simula a hierarquia de caches. Seus números não são contadores
físicos do processador, mas são reproduzíveis e funcionam dentro do container.
Não existe uma métrica genérica de "memória de registradores" em tempo de
execução; o arquivo assembly mostra quais registradores foram escolhidos pelo
compilador.

## Experimentos completos

A série paralela executa as mesmas entradas na versão sequencial e na versão
Pthreads. Por padrão, cada entrada é repetida cinco vezes com 1, 2, 4 e 8
threads:

```bash
docker compose run --rm dev make experiments-complete
```

A quantidade de repetições e a lista de threads podem ser personalizadas:

```bash
docker compose run --rm \
  -e REPETICOES=3 \
  -e THREADS_LISTA="1 2 3 4 6 8" \
  dev make experiments-complete
```

Valores maiores que a quantidade de linhas de uma entrada são ignorados para
essa entrada. A lista deve incluir uma thread para permitir o cálculo da
escalabilidade interna da versão Pthreads. A série gera:

- `resultados/experimentos_completos/execucoes.csv`, com as mesmas métricas de
  tempo, CPU, memória, paginação, contexto e I/O, além da
  quantidade de threads, oversubscription, distribuição das linhas entre os
  participantes, ordem da medição, configuração precedente e condicionamento
  da cache;
- `resultados/experimentos_completos/resumo_desempenho.csv`, com médias,
  medianas, desvios-padrão, mínimos, máximos, speedup, eficiência, utilização de
  CPU, custo e sobrecusto;
- `resultados/experimentos_completos/ambiente_execucao.txt`, com os parâmetros,
  núcleos físicos, processadores lógicos, afinidade, processador, memória,
  compilador e sistema operacional.

O campo `oversubscription` recebe `sim` somente quando a quantidade de
participantes excede os processadores lógicos disponíveis. O uso de mais
participantes que núcleos físicos, mas dentro da capacidade lógica, é tratado
como SMT e a topologia exposta pelo runner é registrada separadamente.

O speedup é calculado dividindo a média sequencial pela média paralela. A
eficiência é calculada dividindo o speedup pela quantidade de threads. A versão
sequencial é executada na mesma série para evitar comparar medições produzidas
em máquinas ou momentos diferentes. O resumo também calcula o speedup de cada
configuração em relação a Pthreads com uma thread, separando o ganho do kernel
do ganho obtido ao aumentar os participantes. Cinco repetições são usadas
localmente por padrão. Cada rodada percorre todas as entradas antes de iniciar
a próxima. O ponto inicial e o sentido do
percurso variam, e as configurações são rotacionadas de acordo com a rodada e a
entrada.
Assim, sequencial e Pthreads ocupam posições diferentes e não mantêm sempre o
mesmo predecessor. Um ciclo completo coloca cada configuração uma vez em cada
posição; o ciclo seguinte usa o sentido inverso. A execução sequencial e a
paralela com uma thread permanecem separadas, pois a segunda mantém a
decomposição e a sincronização da implementação Pthreads, embora execute na
thread principal sem criar uma auxiliar.

O condicionamento da cache é habilitado por padrão. O tamanho do buffer é quatro
vezes a maior cache de dados detectada, limitado automaticamente entre 64 MiB e
512 MiB. Para um estudo específico, ele pode ser desabilitado ou configurado:

```bash
docker compose run --rm \
  -e CONDICIONAR_CACHE=0 \
  dev make experiments-complete

docker compose run --rm \
  -e BYTES_CONDICIONAMENTO_CACHE=134217728 \
  dev make experiments-complete
```

O condicionamento reduz a herança da cache compartilhada, mas não torna as
medições absolutamente independentes. Frequência, temperatura, escalonamento e
interferência do sistema continuam sendo controlados por repetições, ordem
balanceada, medianas e registro do ambiente. A cache de arquivos do sistema não
é descartada, pois a leitura da entrada ocorre fora do tempo da simulação e
forçar sua limpeza afetaria toda a máquina.

Antes de calcular o resumo, o script confere se todas as execuções planejadas
foram registradas, se cada configuração possui a quantidade esperada de
repetições e se o resumo contém todas as configurações paralelas. Uma série
incompleta é interrompida em vez de produzir speedup e eficiência parciais.
O CSV bruto é preservado antes da consolidação, e o resumo só substitui a versão
anterior depois de passar por todas as validações.

O pós-processamento pode ser repetido sem executar novamente as simulações. Por
exemplo, para uma série com 10 repetições, 2.920 medições e 233 configurações
paralelas:

```bash
docker compose run --rm \
  -e REPETICOES=10 \
  dev bash scripts/processar_resultados_experimentos.sh \
    resultados/experimentos_completos 2920 233
```

Os dois últimos argumentos são opcionais em uma análise exploratória. Quando
informados pelo executor da série, eles impedem que um conjunto incompleto seja
aceito como resultado válido.

O workflow `Experimentos completos` é iniciado manualmente no GitHub Actions.
Por padrão, ele executa cada configuração dez vezes com 1, 2, 4 e 8 threads. A
quantidade de repetições e a lista de threads podem ser alteradas antes de
iniciar a execução. As cargas de desempenho tornam essa série consideravelmente
mais longa, e a duração depende do processador atribuído ao runner.

O workflow compila as duas versões, executa a série completa, coleta Cachegrind,
Massif e `gprof`, e publica no
resumo da execução as tabelas sequencial e paralela. As entradas, os CSVs, o
ambiente, o profiling e o relatório são armazenados como artefato por 30 dias.

## Perfil de desempenho

Gere o perfil da versão sequencial com `gprof`:

```bash
docker compose run --rm dev make profile-sequential-gprof \
  INPUT=entradas/exemplo.txt
```

Esse alvo gera um executável separado com `-pg`, desativa o inlining e a
substituição interprocedural de argumentos para preservar as funções no perfil,
omite a impressão do estado final e grava o resultado em
`resultados/perfil_sequencial/gprof.txt`. Os executáveis usados nos experimentos
permanecem separados e otimizados com `-O2`.

## Limpeza

Remova os binários e os dados gerados pelo profiling:

```bash
docker compose run --rm dev make clean
```
