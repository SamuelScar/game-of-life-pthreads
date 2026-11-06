#!/usr/bin/env python3

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Estado:
    geracoes: int
    linhas: int
    colunas: int
    celulas_vivas: tuple[tuple[int, int], ...]


def interpretar_estado(conteudo: str) -> Estado:
    try:
        valores = [int(valor) for valor in conteudo.split()]
    except ValueError as erro:
        raise ValueError("a entrada deve conter somente números inteiros") from erro

    if len(valores) < 4:
        raise ValueError("a entrada não contém o cabeçalho completo")

    geracoes, linhas, colunas, quantidade_vivas = valores[:4]

    if geracoes < 0:
        raise ValueError("a quantidade de gerações não pode ser negativa")
    if linhas <= 0 or colunas <= 0:
        raise ValueError("as dimensões da matriz devem ser maiores que zero")
    if quantidade_vivas < 0 or quantidade_vivas > linhas * colunas:
        raise ValueError("a quantidade de células vivas é inválida")

    quantidade_esperada = 4 + quantidade_vivas * 2

    if len(valores) != quantidade_esperada:
        raise ValueError("a quantidade de coordenadas não corresponde ao cabeçalho")

    celulas_vivas = []

    for indice in range(4, quantidade_esperada, 2):
        linha, coluna = valores[indice], valores[indice + 1]

        if linha < 0 or linha >= linhas or coluna < 0 or coluna >= colunas:
            raise ValueError(f"coordenada fora da matriz: {linha} {coluna}")

        celulas_vivas.append((linha, coluna))

    if len(set(celulas_vivas)) != quantidade_vivas:
        raise ValueError("a entrada contém coordenadas repetidas")

    return Estado(
        geracoes=geracoes,
        linhas=linhas,
        colunas=colunas,
        celulas_vivas=tuple(celulas_vivas),
    )


def calcular_dimensoes(estado: Estado) -> tuple[int, int]:
    maior_dimensao = max(estado.linhas, estado.colunas)
    escala = min(24.0, 1000.0 / maior_dimensao)

    return (
        max(1, round(estado.colunas * escala)),
        max(1, round(estado.linhas * escala)),
    )


def gerar_svg(estado: Estado) -> str:
    largura, altura = calcular_dimensoes(estado)
    mostrar_grade = max(estado.linhas, estado.colunas) <= 100
    preenchimento_fundo = "url(#grade)" if mostrar_grade else "#ffffff"
    celulas = "\n".join(
        f'  <rect x="{coluna}" y="{linha}" width="1" height="1" />'
        for linha, coluna in estado.celulas_vivas
    )

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="{largura}"
     height="{altura}"
     viewBox="0 0 {estado.colunas} {estado.linhas}"
     preserveAspectRatio="xMidYMid meet"
     shape-rendering="crispEdges">
  <title>Jogo da Vida após {estado.geracoes} gerações</title>
  <desc>{estado.linhas} linhas, {estado.colunas} colunas e {len(estado.celulas_vivas)} células vivas.</desc>
  <defs>
    <pattern id="grade" width="1" height="1" patternUnits="userSpaceOnUse">
      <rect width="1" height="1" fill="#ffffff" />
      <path d="M 1 0 L 0 0 0 1" fill="none" stroke="#d1d5db" stroke-width="0.04" />
    </pattern>
  </defs>
  <rect width="{estado.colunas}" height="{estado.linhas}" fill="{preenchimento_fundo}" />
  <g fill="#111827">
{celulas}
  </g>
</svg>
'''


def ler_entrada(caminho: str) -> str:
    return sys.stdin.read() if caminho == "-" else Path(caminho).read_text(encoding="utf-8")


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Gera um SVG a partir do estado final do Jogo da Vida."
    )
    parser.add_argument(
        "entrada",
        help="arquivo no formato do trabalho ou '-' para ler da entrada padrão",
    )
    parser.add_argument(
        "-o",
        "--saida",
        default="resultados/visualizacoes/estado-final.svg",
        help="arquivo SVG de saída",
    )

    return parser


def main() -> int:
    argumentos = criar_parser().parse_args()

    try:
        estado = interpretar_estado(ler_entrada(argumentos.entrada))
        arquivo_saida = Path(argumentos.saida)
        arquivo_saida.parent.mkdir(parents=True, exist_ok=True)
        arquivo_saida.write_text(gerar_svg(estado), encoding="utf-8")
    except (OSError, ValueError) as erro:
        print(f"Não foi possível gerar o SVG: {erro}.", file=sys.stderr)
        return 1

    print(f"SVG gerado em {arquivo_saida}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
