{
  description = "muscriptor as a Nix flake";

  # Requires the muscriptor model (-large, -medium or -small) gated behind terms of use:
  # https://huggingface.co/MuScriptor/muscriptor-large/resolve/main/model.safetensors

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos-cuda.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
          };
          python = pkgs.python314;
          pythonPackages = pkgs.python314Packages;

          rotary-embedding-torch =
            with pythonPackages;
            buildPythonPackage rec {
              pname = "rotary-embedding-torch";
              version = "0.8.9";
              pyproject = true;

              src = pkgs.fetchPypi {
                pname = "rotary_embedding_torch";
                inherit version;
                hash = "sha256-shPxU8rR0QgGTZMFRPs69njVZRWJPT+GmnoUb4eZfj8=";
              };

              build-system = [
                setuptools
              ];

              dependencies = [
                einops
                torch
              ];

              doCheck = false;
            };

          beat-this =
            with pythonPackages;
            buildPythonPackage rec {
              pname = "beat-this";
              version = "1.1.0";
              pyproject = true;

              src = pkgs.fetchPypi {
                pname = "beat_this";
                inherit version;
                hash = "sha256-MBfHQflylyplDtysz+V2Bof+T1WH/qqYiW2Q+GbCQ1w=";
              };

              build-system = [
                setuptools
                setuptools-scm
              ];

              dependencies = [
                einops
                numpy
                rotary-embedding-torch
                soxr
                torch
                torchaudio
              ];

              doCheck = false;
            };

          soundfont-sf2 = pkgs.fetchurl {
            url = "https://huggingface.co/MuScriptor/assets/resolve/main/MuseScore_General.sf2";
            hash = "sha256-7lHSxLFSXnDxmkWQnE/XouJtkdEV+onb9aa8QT2Lm/M=";
          };

          soundfont-sf3 = pkgs.fetchurl {
            url = "https://huggingface.co/MuScriptor/assets/resolve/main/MuseScore_General.sf3";
            hash = "sha256-W4W2wsYdELK5HN3UHvzOeyXNMcgnHVEcc6+vvvILb6M=";
          };

          muscriptor =
            with pythonPackages;
            buildPythonApplication (finalAttrs: {
              pname = "muscriptor";
              version = "0.3.0";
              pyproject = true;

              src = pkgs.fetchFromGitHub {
                owner = "muscriptor";
                repo = "muscriptor";
                rev = "e34b397bf0584e67bfd81dc591c390e6dcb03350";
                hash = "sha256-UDbj29Q+eON1/pYG1Zdga0QrkDwGHKqfOl123BcpG60=";
              };

              pnpmDeps = pkgs.fetchPnpmDeps {
                inherit (finalAttrs) pname version src;
                sourceRoot = "source/web";
                hash = "sha256-Qd3edZLA6tF1aIc8PWTNtzdugFFHy5rAD3nARqsdKvc=";
                fetcherVersion = 4;
              };

              patches = [
                ./patches/backend-fixes.patch
                ./patches/web-customizations.patch
              ];

              pnpmRoot = "web";

              postPatch = ''
                # Avoids runtime download.
                substituteInPlace muscriptor/soundfonts.py \
                  --replace-fail 'SF2_URL = "hf://MuScriptor/assets/MuseScore_General.sf2"' \
                                 'SF2_URL = "${soundfont-sf2}"' \
                  --replace-fail 'SF3_URL = "hf://MuScriptor/assets/MuseScore_General.sf3"' \
                                 'SF3_URL = "${soundfont-sf3}"'

                # Remove unused assets.
                rm -f web/public/*.mp3 web/public/*-logo* web/public/muscriptor-logo*
              '';

              build-system = [
                hatchling
              ];

              nativeBuildInputs = with pkgs; [
                nodejs
                pnpm
                pnpmConfigHook
              ];

              preBuild = ''
                pnpm --dir web build
              '';

              makeWrapperArgs = [
                "--prefix"
                "PATH"
                ":"
                (lib.makeBinPath (
                  with pkgs;
                  [
                    ffmpeg # For converting unsupported audio.
                    musescore # For sheet generation.
                    fluidsynth # For rendering MIDI.
                  ]
                ))
              ];

              dependencies = [
                torch
                torchaudio
                numpy
                einops
                mido
                packaging
                safetensors
                typer
                fastapi
                uvicorn
                httpx
                python-multipart
                soundfile
                beat-this
              ];

              nativeCheckInputs = [
                pytestCheckHook
              ];

              disabledTestMarks = [
                "integration"
              ];

              disabledTestPaths = [
                "tests/test_download.py"
              ];

              pythonImportsCheck = [
                "muscriptor"
              ];
            });
        in
        {
          inherit muscriptor;
          default = muscriptor;
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.python314
            ];
          };
        }
      );
    };
}
