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

## Visualização do estado final

A saída oficial permanece no formato textual definido pelo trabalho. Para gerar
uma representação visual separada em SVG, execute:

```bash
docker compose run --rm dev make visualizar-sequencial INPUT=entradas/exemplo.txt
```

O arquivo será criado em
`resultados/visualizacoes/estado-final.svg`. Outro caminho pode ser informado
com `SVG_OUTPUT`:

```bash
docker compose run --rm dev make visualizar-sequencial \
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

As 35 entradas podem ser recriadas com:

```bash
docker compose run --rm dev make gerar-entradas-aleatorias
```

Qualquer uma delas pode ser usada com a visualização. Por exemplo:

```bash
docker compose run --rm dev make visualizar-sequencial \
  INPUT=entradas/classicos/planador.txt \
  SVG_OUTPUT=resultados/visualizacoes/planador.svg
```

## Experimentos sequenciais

A série executa todas as entradas de `entradas/classicos/` e
`entradas/aleatorias/`. Cada arquivo define suas próprias dimensões, quantidade
de gerações e células vivas iniciais. Por padrão, cada entrada é executada cinco
vezes localmente:

```bash
docker compose run --rm dev make experiments
```

A quantidade de repetições pode ser personalizada:

```bash
docker compose run --rm \
  -e REPETICOES=3 \
  dev make experiments
```

Cada série gera:

- `resultados/sequencial/execucoes.csv`, com o nome, a categoria, as dimensões
  e todas as medições de cada entrada;
- `resultados/resumo_execucao.md`, com ambiente, médias, desvios-padrão,
  mínimos e máximos.

O workflow `Experimentos sequenciais` é iniciado manualmente no GitHub Actions.
Por padrão, ele executa cada entrada predefinida dez vezes. O único parâmetro do
workflow é a quantidade de repetições.

O relatório é publicado no resumo da execução e os resultados são armazenados
como artefato por 30 dias. Ele apresenta média, desvio-padrão amostral, mínimo e
máximo de cada entrada. Os próprios arquivos usados também fazem parte do
artefato para manter a execução reproduzível.

Os tempos incluem somente a simulação das gerações. A leitura do arquivo e a
escrita do estado final ficam fora da medição. Speedup e eficiência serão
adicionados quando a versão paralela estiver disponível.

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
`resultados/perfil/`:

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
docker compose run --rm dev make profile-detailed
```

O Cachegrind simula a hierarquia de caches. Seus números não são contadores
físicos do processador, mas são reproduzíveis e funcionam dentro do container.
Não existe uma métrica genérica de "memória de registradores" em tempo de
execução; o arquivo assembly mostra quais registradores foram escolhidos pelo
compilador.

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
