#!/usr/bin/env python3

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path


SERIES = {
    2: {"cor": "#0072B2", "traco": "", "marcador": "circulo"},
    4: {"cor": "#D55E00", "traco": "10 5", "marcador": "quadrado"},
    8: {"cor": "#009E73", "traco": "3 4", "marcador": "triangulo"},
}


def media_geometrica(valores: list[float]) -> float:
    return math.exp(sum(math.log(valor) for valor in valores) / len(valores))


def carregar_series(caminho: Path) -> dict[int, list[tuple[int, float]]]:
    grupos: dict[tuple[int, int], list[float]] = defaultdict(list)

    with caminho.open(encoding="utf-8", newline="") as arquivo:
        for linha in csv.DictReader(arquivo):
            participantes = int(linha["threads"])

            if participantes not in SERIES:
                continue

            trabalho = (
                int(linha["linhas"])
                * int(linha["colunas"])
                * int(linha["geracoes"])
            )
            grupos[(participantes, trabalho)].append(
                float(linha["speedup_vs_pthreads_1"])
            )

    return {
        participantes: [
            (trabalho, media_geometrica(grupos[(participantes, trabalho)]))
            for trabalho in sorted(
                trabalho
                for serie, trabalho in grupos
                if serie == participantes
            )
        ]
        for participantes in SERIES
    }


def ponto_marcador(tipo: str, x: float, y: float, cor: str) -> str:
    if tipo == "quadrado":
        return (
            f'<rect x="{x - 4:.2f}" y="{y - 4:.2f}" width="8" height="8" '
            f'fill="{cor}" stroke="#ffffff" stroke-width="1" />'
        )

    if tipo == "triangulo":
        pontos = (
            f"{x:.2f},{y - 5:.2f} "
            f"{x - 5:.2f},{y + 4:.2f} "
            f"{x + 5:.2f},{y + 4:.2f}"
        )
        return (
            f'<polygon points="{pontos}" fill="{cor}" '
            'stroke="#ffffff" stroke-width="1" />'
        )

    return (
        f'<circle cx="{x:.2f}" cy="{y:.2f}" r="4.5" fill="{cor}" '
        'stroke="#ffffff" stroke-width="1" />'
    )


def gerar_painel(
    titulo: str,
    series: dict[int, list[tuple[int, float]]],
    x_inicial: float,
    y_inicial: float,
    largura: float,
    altura: float,
) -> str:
    log_minimo = 2.0
    log_maximo = 10.0
    y_maximo = 2.2

    def converter_x(trabalho: int) -> float:
        return x_inicial + (math.log10(trabalho) - log_minimo) / (
            log_maximo - log_minimo
        ) * largura

    def converter_y(speedup: float) -> float:
        return y_inicial + altura - speedup / y_maximo * altura

    elementos = [
        f'<text x="{x_inicial + largura / 2:.2f}" y="{y_inicial - 25:.2f}" '
        f'class="titulo-painel">{titulo}</text>',
        f'<rect x="{x_inicial}" y="{y_inicial}" width="{largura}" '
        f'height="{altura}" class="area-grafico" />',
    ]

    for valor in (0.0, 0.5, 1.0, 1.5, 2.0):
        y = converter_y(valor)
        classe = "referencia" if valor == 1.0 else "grade"
        elementos.append(
            f'<line x1="{x_inicial}" y1="{y:.2f}" '
            f'x2="{x_inicial + largura}" y2="{y:.2f}" class="{classe}" />'
        )
        elementos.append(
            f'<text x="{x_inicial - 12}" y="{y + 5:.2f}" '
            f'class="rotulo-eixo" text-anchor="end">{valor:.1f}</text>'
        )

    rotulos_potencia = {2: "10²", 4: "10⁴", 6: "10⁶", 8: "10⁸", 10: "10¹⁰"}

    for expoente in (2, 4, 6, 8, 10):
        x = x_inicial + (expoente - log_minimo) / (
            log_maximo - log_minimo
        ) * largura
        elementos.append(
            f'<line x1="{x:.2f}" y1="{y_inicial}" x2="{x:.2f}" '
            f'y2="{y_inicial + altura}" class="grade" />'
        )
        elementos.append(
            f'<text x="{x:.2f}" y="{y_inicial + altura + 24:.2f}" '
            f'class="rotulo-eixo" text-anchor="middle">{rotulos_potencia[expoente]}</text>'
        )

    elementos.append(
        f'<text x="{x_inicial + largura - 8:.2f}" '
        f'y="{converter_y(1.0) - 8:.2f}" class="rotulo-referencia" '
        'text-anchor="end">desempenho de P=1</text>'
    )

    for participantes, pontos in series.items():
        estilo = SERIES[participantes]
        coordenadas = [
            (converter_x(trabalho), converter_y(speedup))
            for trabalho, speedup in pontos
        ]
        caminho = " ".join(
            ("M" if indice == 0 else "L") + f" {x:.2f} {y:.2f}"
            for indice, (x, y) in enumerate(coordenadas)
        )
        traco = (
            f' stroke-dasharray="{estilo["traco"]}"'
            if estilo["traco"]
            else ""
        )
        elementos.append(
            f'<path d="{caminho}" fill="none" stroke="{estilo["cor"]}" '
            f'stroke-width="2.5"{traco} />'
        )
        elementos.extend(
            ponto_marcador(
                estilo["marcador"], x, y, estilo["cor"]
            )
            for x, y in coordenadas
        )

    return "\n".join(elementos)


def gerar_svg(
    series_amd: dict[int, list[tuple[int, float]]],
    series_intel: dict[int, list[tuple[int, float]]],
) -> str:
    largura = 1400
    altura = 1200
    painel_largura = 1180
    painel_altura = 400
    painel_x = 110
    painel_amd_y = 135
    painel_intel_y = 675

    legenda = []
    legenda_x = 430

    for indice, participantes in enumerate(SERIES):
        estilo = SERIES[participantes]
        x = legenda_x + indice * 190
        traco = (
            f' stroke-dasharray="{estilo["traco"]}"'
            if estilo["traco"]
            else ""
        )
        legenda.append(
            f'<line x1="{x}" y1="70" x2="{x + 44}" y2="70" '
            f'stroke="{estilo["cor"]}" stroke-width="3"{traco} />'
        )
        legenda.append(
            ponto_marcador(estilo["marcador"], x + 22, 70, estilo["cor"])
        )
        legenda.append(
            f'<text x="{x + 54}" y="76" class="legenda">P={participantes}</text>'
        )

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{largura}" height="{altura}"
     viewBox="0 0 {largura} {altura}">
  <style>
    text {{ font-family: "DejaVu Sans", sans-serif; fill: #222222; }}
    .titulo {{ font-size: 24px; font-weight: 700; text-anchor: middle; }}
    .titulo-painel {{ font-size: 22px; font-weight: 700; text-anchor: middle; }}
    .legenda {{ font-size: 18px; }}
    .rotulo-eixo {{ font-size: 17px; }}
    .rotulo-referencia {{ font-size: 15px; fill: #555555; }}
    .titulo-eixo {{ font-size: 20px; font-weight: 600; text-anchor: middle; }}
    .area-grafico {{ fill: #ffffff; stroke: #333333; stroke-width: 1.2; }}
    .grade {{ stroke: #d9d9d9; stroke-width: 1; }}
    .referencia {{ stroke: #555555; stroke-width: 1.5; stroke-dasharray: 7 5; }}
  </style>
  <rect width="100%" height="100%" fill="#ffffff" />
  <text x="700" y="32" class="titulo">Speedup interno em função do tamanho da carga</text>
  {''.join(legenda)}
  {gerar_painel('AMD: 1 núcleo físico / 2 CPUs lógicas', series_amd, painel_x, painel_amd_y, painel_largura, painel_altura)}
  {gerar_painel('Intel: 2 núcleos físicos / 4 CPUs lógicas', series_intel, painel_x, painel_intel_y, painel_largura, painel_altura)}
  <text x="700" y="1170" class="titulo-eixo">Atualizações de células (linhas × colunas × gerações, escala logarítmica)</text>
</svg>
'''


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Gera o gráfico de speedup por tamanho de carga do relatório."
    )
    parser.add_argument("resultado_amd", type=Path)
    parser.add_argument("resultado_intel", type=Path)
    parser.add_argument(
        "-o",
        "--saida",
        type=Path,
        default=Path("docs/figuras/speedup-por-carga.svg"),
    )
    return parser


def main() -> int:
    argumentos = criar_parser().parse_args()
    argumentos.saida.parent.mkdir(parents=True, exist_ok=True)
    argumentos.saida.write_text(
        gerar_svg(
            carregar_series(argumentos.resultado_amd),
            carregar_series(argumentos.resultado_intel),
        ),
        encoding="utf-8",
    )
    print(f"Gráfico gerado em {argumentos.saida}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
