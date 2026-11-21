# game-of-life-pthreads

Implementações sequencial e paralela do Jogo da Vida de Conway em C. A versão
sequencial calcula as gerações em uma única thread. A versão paralela utiliza
Pthreads, decomposição horizontal do domínio e sincronização por barreiras. A
quantidade informada inclui a thread principal, que também processa uma faixa de
linhas.

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

## Organização

- `src/sequencial.c`: implementação de referência;
- `src/paralelo.c`: implementação Pthreads;
- `src/simulacao.h`: representação e kernel comuns às duas versões;
- `src/condicionar_cache.c`: condicionamento controlado da cache entre medições;
- `scripts/validar_equivalencia.sh`: comparação funcional antes dos benchmarks;
- `scripts/validar_thread_principal.sh`: verificação local reduzida da
  participação da thread principal;
- `scripts/validar_entradas_invalidas.sh`: verifica rejeição de entradas e parâmetros inválidos;
- `scripts/suporte_experimentos.sh`: detecção e condicionamento da cache;
- `scripts/executar_experimentos_sequenciais.sh`: série apenas sequencial;
- `scripts/executar_experimentos_completos.sh`: comparação sequencial e paralela;
- `scripts/processar_resultados_experimentos.sh`: valida e consolida medições já coletadas;
- `scripts/validar_processamento_resultados.sh`: exercita a consolidação de
  ponta a ponta sobre uma fixture pequena;
- `scripts/coletar_perfil_sequencial.sh`: profiling detalhado da referência;
- `scripts/gerar_relatorio_experimentos.sh`: relatório Markdown das medições;
- `.github/workflows/experimentos-completos.yml`: automação da série completa.

## Compilação

Compile as duas versões com:

```bash
docker compose run --rm dev make
```

Os executáveis `sequencial`, `paralelo` e `condicionar-cache` serão gerados na
pasta `bin/`.

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

Execute a versão paralela informando também a quantidade de threads:

```bash
docker compose run --rm dev make run-parallel \
  INPUT=entradas/exemplo.txt \
  THREADS=4
```

`THREADS` representa o total de participantes do cálculo. A thread principal
processa uma faixa e são criadas `THREADS - 1` threads auxiliares. Com
`THREADS=1`, a principal executa toda a simulação sem criar uma auxiliar.

## Visualização do estado final

A saída oficial permanece no formato textual definido pelo trabalho. Para gerar
uma representação visual separada em SVG, execute:

```bash
docker compose run --rm dev make visualize-sequential INPUT=entradas/exemplo.txt
```

O arquivo será criado em
`resultados/visualizacoes/estado-final.svg`. Outro caminho pode ser informado
com `SVG_OUTPUT`:

```bash
docker compose run --rm dev make visualize-sequential \
  INPUT=entradas/exemplo.txt \
  SVG_OUTPUT=resultados/visualizacoes/exemplo.svg
```

O script também pode converter um estado já salvo, sem executar novamente a
simulação:

```bash
python3 scripts/gerar_svg.py resultado.txt --saida resultado.svg
```

As células vivas são desenhadas em cor escura. Para matrizes de até 100 linhas
ou colunas, o SVG também exibe a grade das células.

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

Essas entradas e as cargas de desempenho descritas a seguir podem ser recriadas
com:

```bash
docker compose run --rm dev make generate-random-inputs
```

### Entradas de desempenho

O diretório `entradas/desempenho/` contém seis cargas maiores, separadas das
entradas pseudoaleatórias de uso geral. Elas combinam matrizes quadradas e
retangulares entre 1024 × 1024 e 8192 × 8192, com até 500 gerações. A maior
configuração utiliza aproximadamente 128 MiB nas duas matrizes da simulação.

Essas entradas foram dimensionadas para produzir execuções sequenciais com
duração suficiente para comparar speedup e eficiência da versão com Pthreads.
Com dez repetições, elas acrescentam aproximadamente 99,6 bilhões de
atualizações de célula à série sequencial.

Qualquer uma delas pode ser usada com a visualização. Por exemplo:

```bash
docker compose run --rm dev make visualize-sequential \
  INPUT=entradas/classicos/planador.txt \
  SVG_OUTPUT=resultados/visualizacoes/planador.svg
```

## Experimentos sequenciais

A série executa todas as entradas de `entradas/classicos/`,
`entradas/aleatorias/` e `entradas/desempenho/`. Cada arquivo define suas
próprias dimensões, quantidade de gerações e células vivas iniciais. Por padrão,
cada entrada é executada cinco vezes localmente:

```bash
docker compose run --rm dev make experiments-sequential
```

A quantidade de repetições pode ser personalizada:

```bash
docker compose run --rm \
  -e REPETICOES=3 \
  dev make experiments-sequential
```

As execuções são intercaladas por rodada. A entrada inicial e o sentido do
percurso variam entre as rodadas, evitando que cada arquivo seja sempre medido
depois do mesmo antecessor. Antes de cada processo temporizado, um programa
auxiliar percorre um buffer maior que a maior cache de dados detectada. Essa
etapa ocorre fora da medição e reduz a dependência do estado deixado pela
execução anterior.

Cada série gera:

- `resultados/sequencial/execucoes.csv`, com o nome, a categoria, as dimensões
  e todas as medições de cada entrada, incluindo a ordem, a execução
  precedente e os parâmetros de condicionamento da cache;
- `resultados/relatorio_experimentos.md`, com ambiente, médias, desvios-padrão,
  mínimos e máximos.

Os tempos incluem somente a simulação das gerações. A leitura do arquivo e a
escrita do estado final ficam fora da medição.

### Métricas de recursos

Cada execução da série registra no CSV:

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

## Validação funcional

Para uma verificação local curta da participação da thread principal, execute:

```bash
docker compose run --rm -T dev make validate-main-thread
```

O teste reduzido compara a versão Pthreads com a sequencial em duas matrizes,
com quantidades par e ímpar de gerações e com 1, 2 e 4 participantes. Cada
execução possui limite de tempo para detectar um possível bloqueio na barreira.
Os arquivos temporários são removidos ao final.

Para repetir o mesmo teste com verificação de vazamentos pelo Valgrind:

```bash
docker compose run --rm -T dev make validate-main-thread-memory
```

Essa variante executa o Memcheck com 1, 2 e 4 participantes em uma das entradas
reduzidas e falha ao encontrar erro de memória ou bloco não liberado.

Antes de medir desempenho, compare as saídas sequencial e Pthreads e confirme
que entradas e parâmetros inválidos são rejeitados:

```bash
docker compose run --rm \
  -e THREADS_LISTA="1 2 4 8" \
  dev make validate
```

Essa etapa inclui matrizes `1x1`, `1xN`, `Nx1`, quantidades pares e ímpares de
gerações, divisões irregulares de linhas, uma thread por linha e entradas
aleatórias com sementes fixas. Também verifica coordenadas repetidas ou fora dos
limites, arquivos incompletos e quantidades inválidas de threads. A validação
ocorre fora da série temporizada e interrompe o fluxo ao encontrar divergência.
A lista de threads deve incluir `1`, usada como baseline da implementação
Pthreads. O mesmo alvo também valida a sintaxe dos scripts Bash e dos blocos
AWK e exercita a consolidação completa sobre uma fixture pequena. Essa
verificação passa pela contagem das medições, validação do CSV, geração do
resumo e conferência das configurações antes de iniciar a etapa longa do
workflow.

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
  tempo, CPU, memória, paginação, contexto e I/O da série sequencial, além da
  quantidade de threads, oversubscription, distribuição das linhas entre os
  participantes, ordem da medição, configuração precedente e condicionamento
  da cache;
- `resultados/experimentos_completos/resumo_desempenho.csv`, com médias,
  medianas, desvios-padrão, mínimos, máximos, speedup, eficiência, utilização de
  CPU, custo e sobrecusto;
- `resultados/experimentos_completos/ambiente_execucao.txt`, com os parâmetros, processadores lógicos,
  afinidade, processador, memória, compilador e sistema operacional.

O speedup é calculado dividindo a média sequencial pela média paralela. A
eficiência é calculada dividindo o speedup pela quantidade de threads. A versão
sequencial é executada na mesma série para evitar comparar medições produzidas
em máquinas ou momentos diferentes. O resumo também calcula o speedup de cada
configuração em relação a Pthreads com uma thread, separando o ganho do kernel
do ganho obtido ao aumentar os participantes. Cinco repetições são usadas
localmente por padrão, assim como na série sequencial. Cada rodada percorre
todas as entradas antes de iniciar a próxima. O ponto inicial e o sentido do
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

O workflow compila as duas versões, valida equivalência e tratamento de erros,
executa a série completa, coleta Cachegrind, Massif e `gprof`, e publica no
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
