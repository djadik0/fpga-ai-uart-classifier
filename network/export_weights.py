
import torch
from pathlib import Path
from rtl_digit_net import RTLDigitNet

MODEL_PATH = "rtl_digit_net.pth"
CONV_MEM_PATH = "buffer_weight_new.mem"
FC_MEM_PATH = "fc_weight_new.mem"
INFO_PATH = "quant_info.txt"

def quantize_symmetric_int8(tensor):
    max_abs = float(tensor.abs().max().item())
    scale = 127.0 / max_abs if max_abs > 0.0 else 1.0
    q = torch.round(tensor * scale).clamp(-128, 127).to(torch.int16)
    return q, scale, max_abs

def int8_to_hex(val: int) -> str:
    return f"{(int(val) & 0xFF):02x}"

def main():
    model = RTLDigitNet()
    state = torch.load(MODEL_PATH, map_location="cpu")
    model.load_state_dict(state)
    model.eval()

    conv_w = model.conv.weight.detach().cpu().squeeze(1)   # [4, 4, 4]
    fc_w = model.fc.weight.detach().cpu()                  # [10, 3600]

    conv_q, conv_scale, conv_max = quantize_symmetric_int8(conv_w)
    fc_q, fc_scale, fc_max = quantize_symmetric_int8(fc_w)

    conv_lines = []
    for f in range(conv_q.shape[0]):
        for y in range(conv_q.shape[1]):
            for x in range(conv_q.shape[2]):
                conv_lines.append(int8_to_hex(conv_q[f, y, x].item()))

    fc_lines = []
    for cls in range(fc_q.shape[0]):
        for idx in range(fc_q.shape[1]):
            fc_lines.append(int8_to_hex(fc_q[cls, idx].item()))

    Path(CONV_MEM_PATH).write_text("\n".join(conv_lines) + "\n", encoding="utf-8")
    Path(FC_MEM_PATH).write_text("\n".join(fc_lines) + "\n", encoding="utf-8")

    info = []
    info.append(f"conv_scale={conv_scale}")
    info.append(f"conv_max_abs={conv_max}")
    info.append(f"fc_scale={fc_scale}")
    info.append(f"fc_max_abs={fc_max}")
    info.append("quantization=symmetric per-layer int8, q=round(w*scale), scale=127/max_abs")
    info.append("conv_order=filter,y,x")
    info.append("fc_order=class,flatten_index")
    info.append("flatten_assumption=PyTorch NCHW flatten => channel/filter major, then y, then x")

    Path(INFO_PATH).write_text("\n".join(info) + "\n", encoding="utf-8")

    print(f"[OK] written {CONV_MEM_PATH} ({len(conv_lines)} values)")
    print(f"[OK] written {FC_MEM_PATH} ({len(fc_lines)} values)")
    print(f"[OK] written {INFO_PATH}")
    print(f"[INFO] conv_scale = {conv_scale}")
    print(f"[INFO] fc_scale   = {fc_scale}")

if __name__ == "__main__":
    main()
