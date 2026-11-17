CC := gcc
PYTHON := python3

CFLAGS := -std=c11 -O2 -Wall -Wextra -Wpedantic
PTHREAD_FLAGS := -pthread
PROFILE_FLAGS := -pg -fno-inline -fno-ipa-sra

BIN_DIR := bin
SEQUENTIAL_BIN := $(BIN_DIR)/sequencial
PARALLEL_BIN := $(BIN_DIR)/paralelo
SEQUENTIAL_GPROF_BIN := $(BIN_DIR)/sequencial-gprof
CACHE_CONDITIONER_BIN := $(BIN_DIR)/condicionar-cache

INPUT ?= entradas/exemplo.txt
THREADS ?= 4
GPROF_OUTPUT ?= resultados/perfil_sequencial/gprof.txt
SEQUENTIAL_EXPERIMENT_SCRIPT := scripts/executar_experimentos_sequenciais.sh
COMPLETE_EXPERIMENT_SCRIPT := scripts/executar_experimentos_completos.sh
EQUIVALENCE_VALIDATION_SCRIPT := scripts/validar_equivalencia.sh
INVALID_INPUT_VALIDATION_SCRIPT := scripts/validar_entradas_invalidas.sh
SVG_SCRIPT := scripts/gerar_svg.py
SVG_OUTPUT ?= resultados/visualizacoes/estado-final.svg
RANDOM_INPUT_SCRIPT := scripts/gerar_entradas_aleatorias.py
SEQUENTIAL_PROFILE_SCRIPT := scripts/coletar_perfil_sequencial.sh

.PHONY: all run-sequential run-parallel visualize-sequential \
	generate-random-inputs experiments-sequential experiments-complete \
	validate validate-equivalence validate-invalid-inputs \
	profile-sequential-gprof \
	profile-sequential-detailed clean

all: $(SEQUENTIAL_BIN) $(PARALLEL_BIN) $(CACHE_CONDITIONER_BIN)

$(BIN_DIR):
	mkdir -p $@

$(SEQUENTIAL_BIN): src/sequencial.c src/simulacao.h | $(BIN_DIR)
	$(CC) $(CFLAGS) $< -o $@

$(PARALLEL_BIN): src/paralelo.c src/simulacao.h | $(BIN_DIR)
	$(CC) $(CFLAGS) $(PTHREAD_FLAGS) $< -o $@

$(SEQUENTIAL_GPROF_BIN): src/sequencial.c src/simulacao.h | $(BIN_DIR)
	$(CC) $(CFLAGS) $(PROFILE_FLAGS) $< -o $@

$(CACHE_CONDITIONER_BIN): src/condicionar_cache.c | $(BIN_DIR)
	$(CC) $(CFLAGS) $< -o $@

run-sequential: $(SEQUENTIAL_BIN)
	$(SEQUENTIAL_BIN) $(INPUT)

run-parallel: $(PARALLEL_BIN)
	$(PARALLEL_BIN) $(INPUT) $(THREADS)

visualize-sequential: $(SEQUENTIAL_BIN)
	$(SEQUENTIAL_BIN) $(INPUT) | $(PYTHON) $(SVG_SCRIPT) - --saida $(SVG_OUTPUT)

generate-random-inputs:
	$(PYTHON) $(RANDOM_INPUT_SCRIPT)

experiments-sequential: $(SEQUENTIAL_BIN) $(CACHE_CONDITIONER_BIN)
	bash $(SEQUENTIAL_EXPERIMENT_SCRIPT)

experiments-complete: $(SEQUENTIAL_BIN) $(PARALLEL_BIN) $(CACHE_CONDITIONER_BIN)
	bash $(COMPLETE_EXPERIMENT_SCRIPT)

validate: validate-equivalence validate-invalid-inputs

validate-equivalence: $(SEQUENTIAL_BIN) $(PARALLEL_BIN)
	bash $(EQUIVALENCE_VALIDATION_SCRIPT)

validate-invalid-inputs: $(SEQUENTIAL_BIN) $(PARALLEL_BIN)
	bash $(INVALID_INPUT_VALIDATION_SCRIPT)

profile-sequential-gprof: $(SEQUENTIAL_GPROF_BIN)
	mkdir -p $(dir $(GPROF_OUTPUT))
	OMITIR_SAIDA=1 $(SEQUENTIAL_GPROF_BIN) $(INPUT)
	gprof $(SEQUENTIAL_GPROF_BIN) gmon.out > $(GPROF_OUTPUT)
	rm -f gmon.out
	chmod a+r $(GPROF_OUTPUT)

profile-sequential-detailed: $(SEQUENTIAL_BIN)
	bash $(SEQUENTIAL_PROFILE_SCRIPT)

clean:
	rm -rf $(BIN_DIR) gmon.out
