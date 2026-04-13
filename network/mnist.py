from pathlib import Path
from torchvision import datasets, transforms
from PIL import Image

out_dir = Path("mnist_png")
out_dir.mkdir(exist_ok=True)

dataset = datasets.MNIST(
    root="./data",
    train=False,
    download=True,
    transform=transforms.ToTensor()
)

for i in range(20):
    img, label = dataset[i]          # img: tensor [1, 28, 28]
    pil = transforms.ToPILImage()(img)
    pil.save(out_dir / f"{i}_digit_{label}.png")

print("saved to", out_dir.resolve())