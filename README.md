# muscriptor as a flake

## Requirements

Model (requires you to accept the terms of use first): https://huggingface.co/MuScriptor/muscriptor-large/resolve/main/model.safetensors

```bash
hf download MuScriptor/muscriptor-large --local-dir /path/to/muscriptor-large
```

## Usage

```bash
nix run github:zopieux/muscriptor -- serve --model /path/to/muscriptor-large/model.safetensors
```

```bash
nix run github:zopieux/muscriptor -- transcribe --model /path/to/muscriptor-large/model.safetensors /path/to/input.mp3
```

Tested successfully with `-large` model sha256 `ac4eb6ea87dfc26b6ca6b954c6b967ab87ad4c7d08e078b25214f13ed051f397`.

## License

Public domain. See https://github.com/muscriptor/muscriptor for the license of the packaged project.
