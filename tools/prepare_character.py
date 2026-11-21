"""Готовит кадры персонажа от художника к игре.

Художник рисует кадры крупно и на холстах разного размера. Скрипт уменьшает их
до игрового роста, выравнивает по корпусу и ступням и сохраняет на одинаковых холстах,
чтобы анимация не дёргалась. Кадры должны быть нарисованы в одном масштабе: поля вокруг
персонажа могут быть любыми, а сам персонаж одного размера.

Запуск:
    python tools/prepare_character.py <папка для результата> <рост в пикселях> <кадр 1> <кадр 2> ...

Нужна библиотека Pillow. Результат: файлы walk_1.png, walk_2.png и так далее.
"""

import statistics
import sys
from pathlib import Path

from PIL import Image

ALPHA_SOLID = 128
TORSO_TOP = 0.28
TORSO_BOTTOM = 0.46


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    """Находит границы персонажа на кадре.

    image: кадр с прозрачным фоном.
    Возвращает левую, верхнюю, правую и нижнюю границы плотных пикселей; полупрозрачный
    мусор по краям не учитывается.
    """
    solid = image.getchannel("A").point(lambda value: 255 if value > ALPHA_SOLID else 0)
    return solid.getbbox()


def torso_center(image: Image.Image) -> float:
    """Находит середину корпуса по горизонтали.

    image: кадр с прозрачным фоном.
    Возвращает координату x центра непрозрачных пикселей в полосе корпуса; по ней кадры
    совмещаются друг с другом.
    """
    alpha = image.getchannel("A")
    left, top, right, bottom = content_box(image)
    band = alpha.crop((left, int(top + (bottom - top) * TORSO_TOP), right, int(top + (bottom - top) * TORSO_BOTTOM)))
    columns = [x for x in range(band.width) for y in range(band.height) if band.getpixel((x, y)) > ALPHA_SOLID]
    return left + statistics.fmean(columns)


def prepare(output_dir: Path, height: int, sources: list[Path]) -> None:
    """Уменьшает и выравнивает кадры и сохраняет их в папку.

    output_dir: папка, куда записать готовые кадры.
    height: рост персонажа в игре в пикселях.
    sources: исходные кадры по порядку анимации.
    Ничего не возвращает; печатает размер готового холста.
    """
    frames = [Image.open(path).convert("RGBA") for path in sources]
    boxes = [content_box(frame) for frame in frames]
    scale = height / statistics.median(box[3] - box[1] for box in boxes)
    centers = [torso_center(frame) for frame in frames]
    reach = max(max(center - box[0], box[2] - center) for center, box in zip(centers, boxes))
    rise = max(box[3] - box[1] for box in boxes)
    half_width = int(reach * scale) + 2
    canvas_size = (half_width * 2, int(rise * scale) + 2)
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, (frame, center, box) in enumerate(zip(frames, centers, boxes), start=1):
        size = (max(round(frame.width * scale), 1), max(round(frame.height * scale), 1))
        small = frame.resize(size, Image.LANCZOS)
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        canvas.alpha_composite(small, (half_width - round(center * scale), canvas_size[1] - round(box[3] * scale)))
        canvas.save(output_dir / f"walk_{index}.png")
    print(f"Кадров: {len(frames)}, холст {canvas_size[0]}x{canvas_size[1]}")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    prepare(Path(sys.argv[1]), int(sys.argv[2]), [Path(value) for value in sys.argv[3:]])
