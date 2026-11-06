#!/usr/bin/env python3

import random
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Configuracao:
    nome: str
    linhas: int
    colunas: int
    geracoes: int
    densidade: int
    semente: int


CONFIGURACOES = (
    Configuracao("quadrada-5x5-d20-s1.txt", 5, 5, 10, 20, 1),
    Configuracao("quadrada-5x5-d40-s2.txt", 5, 5, 10, 40, 2),
    Configuracao("quadrada-5x5-d60-s3.txt", 5, 5, 10, 60, 3),
    Configuracao("quadrada-10x10-d10-s11.txt", 10, 10, 25, 10, 11),
    Configuracao("quadrada-10x10-d25-s12.txt", 10, 10, 25, 25, 12),
    Configuracao("quadrada-10x10-d50-s13.txt", 10, 10, 25, 50, 13),
    Configuracao("quadrada-10x10-d75-s14.txt", 10, 10, 25, 75, 14),
    Configuracao("quadrada-20x20-d10-s101.txt", 20, 20, 100, 10, 101),
    Configuracao("quadrada-20x20-d25-s102.txt", 20, 20, 100, 25, 102),
    Configuracao("quadrada-20x20-d50-s103.txt", 20, 20, 100, 50, 103),
    Configuracao("quadrada-20x20-d75-s104.txt", 20, 20, 100, 75, 104),
    Configuracao("quadrada-40x40-d10-s201.txt", 40, 40, 150, 10, 201),
    Configuracao("quadrada-40x40-d25-s202.txt", 40, 40, 150, 25, 202),
    Configuracao("quadrada-40x40-d50-s203.txt", 40, 40, 150, 50, 203),
    Configuracao("quadrada-40x40-d75-s204.txt", 40, 40, 150, 75, 204),
    Configuracao("quadrada-80x80-d10-s301.txt", 80, 80, 200, 10, 301),
    Configuracao("quadrada-80x80-d25-s302.txt", 80, 80, 200, 25, 302),
    Configuracao("quadrada-80x80-d50-s303.txt", 80, 80, 200, 50, 303),
    Configuracao("quadrada-80x80-d75-s304.txt", 80, 80, 200, 75, 304),
    Configuracao("horizontal-30x90-d10-s401.txt", 30, 90, 150, 10, 401),
    Configuracao("horizontal-30x90-d25-s402.txt", 30, 90, 150, 25, 402),
    Configuracao("horizontal-30x90-d50-s403.txt", 30, 90, 150, 50, 403),
    Configuracao("horizontal-30x90-d75-s404.txt", 30, 90, 150, 75, 404),
    Configuracao("vertical-90x30-d10-s501.txt", 90, 30, 150, 10, 501),
    Configuracao("vertical-90x30-d25-s502.txt", 90, 30, 150, 25, 502),
    Configuracao("vertical-90x30-d50-s503.txt", 90, 30, 150, 50, 503),
    Configuracao("vertical-90x30-d75-s504.txt", 90, 30, 150, 75, 504),
    Configuracao("quadrada-256x256-d5-s601.txt", 256, 256, 100, 5, 601),
    Configuracao("quadrada-256x256-d10-s602.txt", 256, 256, 100, 10, 602),
    Configuracao("quadrada-256x256-d25-s603.txt", 256, 256, 100, 25, 603),
    Configuracao("quadrada-512x512-d2-s701.txt", 512, 512, 50, 2, 701),
    Configuracao("quadrada-512x512-d5-s702.txt", 512, 512, 50, 5, 702),
    Configuracao("quadrada-1024x1024-d1-s801.txt", 1024, 1024, 20, 1, 801),
    Configuracao("horizontal-256x1024-d2-s901.txt", 256, 1024, 30, 2, 901),
    Configuracao("vertical-1024x256-d2-s902.txt", 1024, 256, 30, 2, 902),
)


def gerar_conteudo(configuracao: Configuracao) -> str:
    quantidade_celulas = configuracao.linhas * configuracao.colunas
    quantidade_vivas = quantidade_celulas * configuracao.densidade // 100
    gerador = random.Random(configuracao.semente)
    indices = sorted(gerador.sample(range(quantidade_celulas), quantidade_vivas))
    coordenadas = (
        f"{indice // configuracao.colunas} {indice % configuracao.colunas}"
        for indice in indices
    )

    linhas = [
        str(configuracao.geracoes),
        f"{configuracao.linhas} {configuracao.colunas}",
        str(quantidade_vivas),
        *coordenadas,
    ]

    return "\n".join(linhas) + "\n"


def main() -> None:
    raiz_projeto = Path(__file__).resolve().parent.parent
    diretorio_saida = raiz_projeto / "entradas" / "aleatorias"
    diretorio_saida.mkdir(parents=True, exist_ok=True)

    for configuracao in CONFIGURACOES:
        arquivo_saida = diretorio_saida / configuracao.nome
        arquivo_saida.write_text(gerar_conteudo(configuracao), encoding="utf-8")

    print(f"{len(CONFIGURACOES)} entradas aleatórias geradas em {diretorio_saida}")


if __name__ == "__main__":
    main()
