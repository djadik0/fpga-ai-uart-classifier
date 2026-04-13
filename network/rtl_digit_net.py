import torch
import torch.nn as nn


class RTLDigitNet(nn.Module):
    def __init__(self):
        super().__init__()

        self.conv = nn.Conv2d(
            in_channels=1,
            out_channels=4,
            kernel_size=4,
            stride=1,
            padding=0,
            bias=False
        )

        self.pool = nn.MaxPool2d(
            kernel_size=2,
            stride=2
        )

        self.fc = nn.Linear(
            in_features=4 * 30 * 30,
            out_features=10,
            bias=False
        )

    def forward(self, x):
        x = self.conv(x)
        x = self.pool(x)
        x = torch.flatten(x, start_dim=1)
        x = self.fc(x)
        return x


if __name__ == "__main__":
    model = RTLDigitNet()
    x = torch.randn(1, 1, 64, 64)
    y = model(x)

    print(x.shape)
    print(y.shape)