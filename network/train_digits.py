import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

from rtl_digit_net import RTLDigitNet


BATCH_SIZE = 128
EPOCHS = 60
LEARNING_RATE = 3e-4
WEIGHT_DECAY = 1e-4
MODEL_PATH = "rtl_digit_net.pth"

CANVAS_SIZE = 64
DIGIT_SIZE = 40
PAD = (CANVAS_SIZE - DIGIT_SIZE) // 2


class AddGaussianNoise:
    def __init__(self, std=0.02):
        self.std = std

    def __call__(self, x):
        noise = torch.randn_like(x) * self.std
        return torch.clamp(x + noise, 0.0, 1.0)


def evaluate(model, loader, device):
    model.eval()
    correct = 0
    total = 0
    loss_sum = 0.0
    criterion = nn.CrossEntropyLoss()

    with torch.no_grad():
        for images, labels in loader:
            images = images.to(device)
            labels = labels.to(device)

            outputs = model(images)
            loss = criterion(outputs, labels)

            loss_sum += loss.item() * labels.size(0)
            preds = outputs.argmax(dim=1)
            correct += (preds == labels).sum().item()
            total += labels.size(0)

    return loss_sum / total, correct / total


def main():
    torch.manual_seed(42)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[INFO] device = {device}")

    train_transform = transforms.Compose([
        transforms.Resize((DIGIT_SIZE, DIGIT_SIZE)),
        transforms.Pad(PAD, fill=0),

        transforms.RandomAffine(
            degrees=10,
            translate=(0.10, 0.10),
            scale=(0.88, 1.12),
            shear=(-6, 6),
            fill=0
        ),

        transforms.RandomApply([
            transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 0.7))
        ], p=0.20),

        transforms.ToTensor(),

        transforms.RandomApply([
            AddGaussianNoise(std=0.02)
        ], p=0.20),
    ])

    test_transform = transforms.Compose([
        transforms.Resize((DIGIT_SIZE, DIGIT_SIZE)),
        transforms.Pad(PAD, fill=0),
        transforms.ToTensor(),
    ])

    train_dataset = datasets.MNIST(
        root="./data",
        train=True,
        download=True,
        transform=train_transform
    )

    test_dataset = datasets.MNIST(
        root="./data",
        train=False,
        download=True,
        transform=test_transform
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
        num_workers=0
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=0
    )

    model = RTLDigitNet().to(device)
    criterion = nn.CrossEntropyLoss()

    optimizer = optim.AdamW(
        model.parameters(),
        lr=LEARNING_RATE,
        weight_decay=WEIGHT_DECAY
    )

    scheduler = optim.lr_scheduler.StepLR(
        optimizer,
        step_size=10,
        gamma=0.5
    )

    best_acc = 0.0

    for epoch in range(EPOCHS):
        model.train()
        running_loss = 0.0
        total = 0
        correct = 0

        for images, labels in train_loader:
            images = images.to(device)
            labels = labels.to(device)

            optimizer.zero_grad()

            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * labels.size(0)
            preds = outputs.argmax(dim=1)
            correct += (preds == labels).sum().item()
            total += labels.size(0)

        scheduler.step()

        train_loss = running_loss / total
        train_acc = correct / total
        test_loss, test_acc = evaluate(model, test_loader, device)

        print(
            f"[EPOCH {epoch + 1}/{EPOCHS}] "
            f"train_loss={train_loss:.4f} "
            f"train_acc={train_acc:.4f} "
            f"test_loss={test_loss:.4f} "
            f"test_acc={test_acc:.4f} "
            f"lr={scheduler.get_last_lr()[0]:.6f}"
        )

        if test_acc > best_acc:
            best_acc = test_acc
            torch.save(model.state_dict(), MODEL_PATH)
            print(f"[INFO] saved best model to {MODEL_PATH}")

    print(f"[DONE] best test_acc = {best_acc:.4f}")


if __name__ == "__main__":
    main()