import argparse
import sys
import time
from pathlib import Path

import serial
from PIL import Image


START_BYTE = 0xA5
IMAGE_SIZE = 64
DEFAULT_BAUD = 115200
SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}


def find_default_image():
    script_dir = Path(__file__).resolve().parent

    preferred_names = [
        "input.png",
        "image.png",
        "test.png",
        "input.jpg",
        "image.jpg",
        "test.jpg",
    ]

    for name in preferred_names:
        candidate = script_dir / name
        if candidate.exists() and candidate.is_file():
            return candidate

    images = sorted(
        [
            p for p in script_dir.iterdir()
            if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
        ]
    )

    if images:
        return images[0]

    raise FileNotFoundError(
        f"Рядом со скриптом не найдено ни одной картинки.\n"
        f"Положи файл, например, input.png в папку:\n{script_dir}"
    )


def prepare_image(image_path: Path, binarize: bool = False, threshold: int = 127, invert: bool = False):
    if not image_path.exists():
        raise FileNotFoundError(f"Файл не найден: {image_path}")

    img = Image.open(image_path).convert("L")
    img = img.resize((IMAGE_SIZE, IMAGE_SIZE), Image.Resampling.LANCZOS)

    pixels = list(img.getdata())

    if invert:
        pixels = [255 - p for p in pixels]

    if binarize:
        pixels = [255 if p >= threshold else 0 for p in pixels]

    payload = bytes(pixels)
    return img, payload


def send_image_and_get_class(
    port: str,
    image_path: str | None,
    baudrate: int = DEFAULT_BAUD,
    timeout: float = 10.0,
    open_delay: float = 0.2,
    save_prepared: bool = False,
    binarize: bool = False,
    threshold: int = 127,
    invert: bool = False,
):
    if image_path is None:
        image_file = find_default_image()
    else:
        image_file = Path(image_path)

    print(f"[INFO] Использую изображение: {image_file}")

    img, payload = prepare_image(
        image_file,
        binarize=binarize,
        threshold=threshold,
        invert=invert,
    )

    if len(payload) != IMAGE_SIZE * IMAGE_SIZE:
        raise ValueError(f"Неверный размер payload: {len(payload)} байт")

    if save_prepared:
        debug_name = image_file.parent / f"{image_file.stem}_prepared_64x64.png"
        img.save(debug_name)
        print(f"[INFO] Сохранено подготовленное изображение: {debug_name}")

    packet = bytes([START_BYTE]) + payload

    print(f"[INFO] Открываю порт: {port}")
    print(f"[INFO] Baudrate: {baudrate}")
    print(f"[INFO] Отправляю: 1 стартовый байт + {len(payload)} байт изображения")

    with serial.Serial(
        port=port,
        baudrate=baudrate,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=timeout,
    ) as ser:
        time.sleep(open_delay)

        ser.reset_input_buffer()
        ser.reset_output_buffer()

        written = ser.write(packet)
        ser.flush()

        print(f"[INFO] Отправлено байт: {written}")
        print("[INFO] Жду ответ class_id от FPGA...")

        response = ser.read(1)

        if len(response) != 1:
            raise TimeoutError("Не получен ответ от FPGA: таймаут при чтении class_id")

        class_id = response[0]
        print(f"[RESULT] class_id = {class_id}")
        return class_id


def main():
    parser = argparse.ArgumentParser(description="Загрузка изображения 64x64 в FPGA по UART")
    parser.add_argument("image", nargs="?", default=None, help="Путь к изображению (необязательно)")
    parser.add_argument("--port", required=True, help="COM-порт, например COM5")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD, help="Скорость UART")
    parser.add_argument("--timeout", type=float, default=10.0, help="Таймаут ожидания ответа в секундах")
    parser.add_argument("--open-delay", type=float, default=0.2, help="Пауза после открытия порта")
    parser.add_argument("--save-prepared", action="store_true", help="Сохранить подготовленное 64x64 изображение")
    parser.add_argument("--binarize", action="store_true", help="Преобразовать изображение в 0/255")
    parser.add_argument("--threshold", type=int, default=127, help="Порог для binarize")
    parser.add_argument("--invert", action="store_true", help="Инвертировать пиксели")

    args = parser.parse_args()

    try:
        send_image_and_get_class(
            port=args.port,
            image_path=args.image,
            baudrate=args.baud,
            timeout=args.timeout,
            open_delay=args.open_delay,
            save_prepared=args.save_prepared,
            binarize=args.binarize,
            threshold=args.threshold,
            invert=args.invert,
        )
    except Exception as e:
        print(f"[ERROR] {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()