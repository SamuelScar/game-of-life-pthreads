CC := gcc

CFLAGS := -std=c11 -O2 -Wall -Wextra -Wpedantic
PTHREAD_FLAGS := -pthread
PROFILE_FLAGS := -pg

BIN_DIR := bin
SEQUENTIAL_BIN := $(BIN_DIR)/sequencial
PARALLEL_BIN := $(BIN_DIR)/paralelo

INPUT ?= entradas/exemplo.txt
THREADS ?= 4
EXPERIMENT_SCRIPT := scripts/executar_experimentos.sh

.PHONY: all run run-sequential experiments profile clean

all: $(SEQUENTIAL_BIN)

$(BIN_DIR):
	mkdir -p $@

$(SEQUENTIAL_BIN): src/sequencial.c | $(BIN_DIR)
	$(CC) $(CFLAGS) $< -o $@

$(PARALLEL_BIN): src/paralelo.c | $(BIN_DIR)
	$(CC) $(CFLAGS) $(PTHREAD_FLAGS) $< -o $@

run: $(PARALLEL_BIN)
	$(PARALLEL_BIN) $(INPUT) $(THREADS)

run-sequential: $(SEQUENTIAL_BIN)
	$(SEQUENTIAL_BIN) $(INPUT)

experiments: $(SEQUENTIAL_BIN)
	bash $(EXPERIMENT_SCRIPT)

profile: CFLAGS += $(PROFILE_FLAGS)
profile: clean $(SEQUENTIAL_BIN)
	$(SEQUENTIAL_BIN) $(INPUT)
	gprof $(SEQUENTIAL_BIN) gmon.out

clean:
	rm -rf $(BIN_DIR) gmon.out
