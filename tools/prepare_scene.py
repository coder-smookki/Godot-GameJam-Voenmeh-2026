"""Готовит слои сцены от художника к игре.

Художник рисует фон и слои поверх него крупно, иногда с разным разрешением. Скрипт
приводит все слои к одному холсту игровой высоты и убирает почти прозрачный мусор,
который остаётся после вырезания фона.

Запуск:
    python tools/prepare_scene.py <папка для результата> <высота в пикселях> <имя=файл> <имя=файл> ...

Первый файл задаёт пропорции холста. Нужна библиотека Pillow.
Результат: файлы <имя>.png одинакового размера.
"""

import sys
from pathlib import Path

from PIL import Image

ALPHA_NOISE = 40


def prepare(output_dir: Path, height: int, layers: list[tuple[str, Path]]) -> None:
    """Уменьшает слои до общего холста и сохраняет их в папку.

    output_dir: папка, куда записать готовые слои.
    height: высота холста в игре в пикселях.
    layers: пары «имя результата, исходный файл»; первый слой задаёт пропорции.
    Ничего не возвращает; печатает размер готового холста.
    """
    first = Image.open(layers[0][1])
    size = (round(first.width * height / first.height), height)
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, path in layers:
        layer = Image.open(path).convert("RGBA").resize(size, Image.LANCZOS)
        alpha = layer.getchannel("A").point(lambda value: 0 if value < ALPHA_NOISE else value)
        layer.putalpha(alpha)
        layer.save(output_dir / f"{name}.png")
    print(f"Слоёв: {len(layers)}, холст {size[0]}x{size[1]}")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    pairs = [value.split("=", 1) for value in sys.argv[3:]]
    prepare(Path(sys.argv[1]), int(sys.argv[2]), [(name, Path(path)) for name, path in pairs])
