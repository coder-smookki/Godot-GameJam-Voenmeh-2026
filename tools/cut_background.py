"""Убирает белый фон вокруг персонажа, если художник сохранил кадр без прозрачности.

Прозрачным становится только белое, которое соединено с краями картинки: белая рубашка
или белки глаз внутри контура остаются. Светлая кайма вдоль контура срезается.

Если внутри контура остался замкнутый кусок фона (просвет между рукой и телом),
укажите любую его точку: она тоже станет прозрачной вместе со всем белым вокруг неё.

Запуск:
    python tools/cut_background.py <исходный файл> <файл результата> [x,y ...]
Нужна библиотека Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

WHITE_FROM = 240
FRINGE = 2
OUTSIDE = 128


def outside_mask(image: Image.Image, holes: list[tuple[int, int]]) -> Image.Image:
    """Находит фон: белые пиксели, до которых можно дойти от края картинки или от точек holes.

    image: кадр на белом фоне в режиме RGB.
    holes: точки внутри замкнутых кусков фона, в координатах исходной картинки.
    Возвращает маску: 255 на фоне и на кайме вокруг персонажа, 0 на самом персонаже.
    """
    red, green, blue = image.split()
    darkest = ImageChops.darker(ImageChops.darker(red, green), blue)
    white = darkest.point(lambda value: 255 if value >= WHITE_FROM else 0)
    framed = Image.new("L", (white.width + 2, white.height + 2), 255)
    framed.paste(white, (1, 1))
    for x, y in [(-1, -1)] + holes:
        if framed.getpixel((x + 1, y + 1)) == 255:
            ImageDraw.floodfill(framed, (x + 1, y + 1), OUTSIDE)
    reached = framed.crop((1, 1, white.width + 1, white.height + 1))
    mask = reached.point(lambda value: 255 if value == OUTSIDE else 0)
    return mask.filter(ImageFilter.MaxFilter(FRINGE * 2 + 1))


def cut(source: Path, target: Path, holes: list[tuple[int, int]]) -> None:
    """Делает внешний белый фон прозрачным и сохраняет результат.

    source: кадр на белом фоне.
    target: куда записать кадр с прозрачным фоном.
    holes: точки внутри замкнутых кусков фона, которые тоже надо убрать.
    Ничего не возвращает; печатает долю убранных пикселей.
    """
    image = Image.open(source).convert("RGB")
    mask = outside_mask(image, holes)
    result = image.convert("RGBA")
    result.putalpha(ImageChops.invert(mask))
    target.parent.mkdir(parents=True, exist_ok=True)
    result.save(target)
    removed = mask.histogram()[255] / (mask.width * mask.height)
    print(f"Убрано фона: {removed:.0%}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    points = [tuple(int(part) for part in value.split(",")) for value in sys.argv[3:]]
    cut(Path(sys.argv[1]), Path(sys.argv[2]), points)
