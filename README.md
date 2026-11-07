# Corkathon
Team of 3 making dirt

Machine learning in [Century](century/CENTURY.md), a compiled language that turns `.cy` files into native x86-64 code and runs marked loops on every CPU thread (`cpu do`) or on the GPU (`gpu do`). Everything here is Century, with no Python.

## Running programs

From the repo root, in cmd or PowerShell:

```
.\cy --device                                   # what Century will use on this machine (CPU, GPU)
.\cy examples\policy.cy                         # type-check only
.\cy examples\policy.cy --jit run --arg 21      # compile to native code and run run(21)
.\cy examples\policy.cy --entry run --build policy.exe
```

`cy.cmd` calls `century\bin\century.exe`. Run programs from the repo root: `readfile` and `writefile` paths such as `data/eeg_eye.bin` are relative to the current folder.

The compiler needs the three MinGW runtime DLLs beside it in `century\bin`, and so does every program `--build` makes, because a built program is a copy of the compiler with the machine code appended. Add `century\bin` to your `PATH` and both run from anywhere, with no MinGW install.

`century/CENTURY.md` is the language manual: syntax, types, `gpu do` / `cpu do`, built-ins, flags and error messages.

## Layout

| Folder | What it holds |
|---|---|
| `century/` | The compiler (`bin/century.exe` and its DLLs) and the manual |
| `lib/nn/` | Layers and training: `conv` (CNN convolutions), `bnorm`, `dense`, `dropout`, `gru`, `attention`, `gemm` (packed AVX2 matrix multiply), `fused` and `fusedback` (fused forward and backward passes), `chain`, `loss`, `ops`, `optim` |
| `lib/tensor/` | Tensors |
| `lib/models/` | `eegnet` (a compact CNN, trained end to end) and `gpt2` |
| `lib/image/` | JPEG (baseline, grey and colour) and PNG decoders, PNG writer, bilinear resize |
| `lib/format/` | Model weight files: safetensors, GGUF |
| `lib/io/` | Bytes, files, inflate, zip, npz, parquet, text |
| `lib/learn/`, `lib/features/`, `lib/data/` | k-means, signal features (Goertzel, EEG), the EEG recording reader |
| `lib/math/`, `lib/rng/` | Scalar and vector maths, Cholesky, eigenvalues, FFT; random number generators |
| `examples/` | Programs built on the library (below) |
| `data/` | Input data. `eeg_eye.bin` is the recording `eegnet_train.cy` trains on |

A file loads another with `require`, relative to itself: `mut cv = require("../lib/nn/conv.cy")`.

## Examples

| File | Run | What it does |
|---|---|---|
| `eegnet_train.cy` | `--jit run --arg 3` | Trains EEGNet, a CNN, on raw EEG windows. `arg` is epochs * 2 + split; returns train and test accuracy |
| `tblock.cy` | `--jit run --arg 3` | One pre-norm transformer block |
| `policy.cy`, `deep.cy` | `--jit run --arg 21` | 4- and 24-layer policy networks at batch one |
| `trainstep.cy` | `--jit step_all --arg 10` | Where a training step's time goes, piece by piece |

## Notes

- `century/bin/century.exe` is the compiler built from C++ source on 28 Oct 2026 (`century_cpp.exe` in `E:\Prong\Century\CenturyWindows`). The newer self-hosted build there hangs on `deep.cy`, `policy.cy` and `trainstep.cy`; this one compiles everything in `lib/` and `examples/`.
- `lib/models/gpt2.cy` reads its weights from `data/models/gpt2.safetensors`, which is not included (548 MB).
