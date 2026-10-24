# Third-party notices

Resenha includes or downloads the components below. They are not owned by the
Resenha project.

## whisper.cpp

- Project: https://github.com/ggml-org/whisper.cpp
- Pinned version: v1.8.2 (`4979e04f5dcaccb36057e059bbaed8a2f5288315`)
- Copyright: 2023–2024 The ggml authors
- License: MIT
- Full license: [`Vendor/whisper.cpp/LICENSE`](Vendor/whisper.cpp/LICENSE)

## OpenAI Whisper model weights

- Project: https://github.com/openai/whisper
- Download source: https://huggingface.co/ggerganov/whisper.cpp
- Default file: `ggml-small-q5_1.bin`
- Copyright: 2022 OpenAI
- License: MIT

The model is downloaded only after the user chooses **Baixar**. Resenha checks
its exact byte count and SHA-256 digest before installation.

The Windows installer includes `Windows/Installer/LICENSES.txt`. Release builds
must also include the original `Vendor/whisper.cpp/LICENSE` file inside the
installed `licenses` directory. Microsoft-signed .NET runtime files retain their
vendor signatures and are not re-signed by the Resenha publisher.
