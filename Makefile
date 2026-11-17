CC := gcc
PYTHON := python3

CFLAGS := -std=c11 -O2 -Wall -Wextra -Wpedantic
PTHREAD_FLAGS := -pthread
PROFILE_FLAGS := -pg -fno-inline -fno-ipa-sra

BIN_DIR := bin
SEQUENTIAL_BIN := $(BIN_DIR)/sequencial
PARALLEL_BIN := $(BIN_DIR)/paralelo

INPUT ?= entradas/exemplo.txt
THREADS ?= 4
SEQUENTIAL_EXPERIMENT_SCRIPT := scripts/executar_experimentos_sequenciais.sh
COMPLETE_EXPERIMENT_SCRIPT := scripts/executar_experimentos_completos.sh
SVG_SCRIPT := scripts/gerar_svg.py
SVG_OUTPUT ?= resultados/visualizacoes/estado-final.svg
RANDOM_INPUT_SCRIPT := scripts/gerar_entradas_aleatorias.py
SEQUENTIAL_PROFILE_SCRIPT := scripts/coletar_perfil_sequencial.sh

.PHONY: all run-sequential run-parallel visualize-sequential \
	generate-random-inputs experiments-sequential experiments-complete \
	profile-sequential-gprof profile-sequential-detailed clean

all: $(SEQUENTIAL_BIN) $(PARALLEL_BIN)

$(BIN_DIR):
	mkdir -p $@

$(SEQUENTIAL_BIN): src/sequencial.c | $(BIN_DIR)
	$(CC) $(CFLAGS) $< -o $@

$(PARALLEL_BIN): src/paralelo.c | $(BIN_DIR)
	$(CC) $(CFLAGS) $(PTHREAD_FLAGS) $< -o $@

run-sequential: $(SEQUENTIAL_BIN)
	$(SEQUENTIAL_BIN) $(INPUT)

run-parallel: $(PARALLEL_BIN)
	$(PARALLEL_BIN) $(INPUT) $(THREADS)

visualize-sequential: $(SEQUENTIAL_BIN)
	$(SEQUENTIAL_BIN) $(INPUT) | $(PYTHON) $(SVG_SCRIPT) - --saida $(SVG_OUTPUT)

generate-random-inputs:
	$(PYTHON) $(RANDOM_INPUT_SCRIPT)

experiments-sequential: $(SEQUENTIAL_BIN)
	bash $(SEQUENTIAL_EXPERIMENT_SCRIPT)

experiments-complete: $(SEQUENTIAL_BIN) $(PARALLEL_BIN)
	bash $(COMPLETE_EXPERIMENT_SCRIPT)

profile-sequential-gprof: CFLAGS += $(PROFILE_FLAGS)
profile-sequential-gprof: clean $(SEQUENTIAL_BIN)
	OMITIR_SAIDA=1 $(SEQUENTIAL_BIN) $(INPUT)
	gprof $(SEQUENTIAL_BIN) gmon.out

profile-sequential-detailed: $(SEQUENTIAL_BIN)
	bash $(SEQUENTIAL_PROFILE_SCRIPT)

clean:
	rm -rf $(BIN_DIR) gmon.out
