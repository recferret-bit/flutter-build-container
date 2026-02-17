# flutter-build-container

Docker-based CI/CD build container for **Survival Syndicate** Flutter projects. Provides a reproducible environment with the Flutter SDK, Dart analysis tools, and test runners for use in cloud CI/CD pipelines.

## What's Inside

- **Ubuntu 22.04** base image
- **Flutter SDK 3.41.1** (stable) with **Dart 3.11.0**
- Pre-cached Flutter tooling (no Android/iOS/Web — headless CI only)
- CI scripts baked into the image at `/opt/scripts/`
- `build_runner` code generation support
- `very_good_analysis` static analysis
- Unit & widget test runner with coverage output
- CRLF-safe — `sed` strips `\r` from scripts at build time

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- Your Flutter project source code accessible locally

### 1. Build the Base Image

```bash
docker build --target base -t flutter-build-container:base .
```

This creates a reusable image with just the Flutter SDK (~2.5 GB). Use this as a base for CI pipelines where the source code is mounted at runtime.

### 2. Run the CI Pipeline Locally

Mount your Flutter project into the container and run the baked-in CI script:

```bash
docker run --rm -v /path/to/your-app:/app -w /app flutter-build-container:base bash /opt/scripts/ci.sh
```

On **Windows (PowerShell)**:

```powershell
docker run --rm -v /path/to/your-app:/app -w /app flutter-build-container:base bash /opt/scripts/ci.sh
```

> **Note:** The CI scripts are baked into the image at `/opt/scripts/` during build — no extra volume mount is needed.

### 3. Run Individual Steps

You can run any step independently:

```bash
# Just run tests
docker run --rm -v /path/to/project:/app -w /app flutter-build-container:base \
  flutter test --coverage --reporter=expanded

# Just run analysis
docker run --rm -v /path/to/project:/app -w /app flutter-build-container:base \
  flutter analyze --no-fatal-infos

# Just check formatting
docker run --rm -v /path/to/project:/app -w /app flutter-build-container:base \
  dart format --set-exit-if-changed .
```

### 4. Full Baked Build (CI Stage)

To run the entire pipeline as a Docker build (useful for verifying everything passes):

```bash
# Run from the Flutter project directory, NOT this repo
docker build -f /path/to/flutter-build-container/Dockerfile --target ci .
```

This copies your source into the image and runs codegen → analyze → format → test as build steps. A non-zero exit on any step fails the build.

## CI Script Options

The `scripts/ci.sh` script supports environment variables to skip individual stages:

| Variable | Default | Description |
|---|---|---|
| `SKIP_CODEGEN` | `false` | Skip `build_runner` code generation |
| `SKIP_ANALYZE` | `false` | Skip `flutter analyze` |
| `SKIP_FORMAT` | `false` | Skip `dart format` check |
| `SKIP_TESTS` | `false` | Skip `flutter test` |

Example — run only tests:

```bash
docker run --rm -e SKIP_CODEGEN=true -e SKIP_ANALYZE=true -e SKIP_FORMAT=true -v /path/to/project:/app -w /app flutter-build-container:base bash /opt/scripts/ci.sh
```

## Deployment Guide

### Pushing to a Container Registry

Build and push the **base** image to your registry of choice:

```bash
# Docker Hub
docker build --target base -t yourdockerhub/flutter-build-container:3.41.1 .
docker push yourdockerhub/flutter-build-container:3.41.1

# GitHub Container Registry (ghcr.io)
docker build --target base -t ghcr.io/your-org/flutter-build-container:3.41.1 .
docker push ghcr.io/your-org/flutter-build-container:3.41.1

# Google Artifact Registry
docker build --target base -t us-docker.pkg.dev/PROJECT_ID/REPO/flutter-build-container:3.41.1 .
docker push us-docker.pkg.dev/PROJECT_ID/REPO/flutter-build-container:3.41.1
```

### GitHub Actions

```yaml
# .github/workflows/ci.yml
name: Flutter CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/your-org/flutter-build-container:3.41.1
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: flutter pub get

      - name: Code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze --no-fatal-infos

      - name: Format check
        run: dart format --set-exit-if-changed .

      - name: Test
        run: flutter test --coverage --reporter=expanded
```

### Google Cloud Build

```yaml
# cloudbuild.yaml
steps:
  - name: 'us-docker.pkg.dev/$PROJECT_ID/REPO/flutter-build-container:3.41.1'
    entrypoint: bash
    args:
      - '-c'
      - |
        flutter pub get
        dart run build_runner build --delete-conflicting-outputs
        flutter analyze --no-fatal-infos
        dart format --set-exit-if-changed .
        flutter test --coverage --reporter=expanded
```

### GitLab CI/CD

```yaml
# .gitlab-ci.yml
image: registry.gitlab.com/your-org/flutter-build-container:3.41.1

stages:
  - test

flutter_ci:
  stage: test
  script:
    - flutter pub get
    - dart run build_runner build --delete-conflicting-outputs
    - flutter analyze --no-fatal-infos
    - dart format --set-exit-if-changed .
    - flutter test --coverage --reporter=expanded
  only:
    - merge_requests
    - main
```

## Customizing the Flutter Version

Override the Flutter version at build time:

```bash
docker build --target base \
  --build-arg FLUTTER_VERSION=3.38.9 \
  -t flutter-build-container:3.38.9 .
```

## Project Structure

```
flutter-build-container/
├── Dockerfile          # Multi-stage Dockerfile (base + ci stages)
├── .dockerignore       # Excludes unnecessary files from build context
├── .gitattributes      # Forces LF line endings for *.sh and Dockerfile
├── scripts/
│   └── ci.sh           # CI pipeline entrypoint (baked into image at /opt/scripts/)
└── README.md           # This file
```

## Troubleshooting

**Build fails at `flutter pub get`**
- Ensure `pubspec.yaml` and `pubspec.lock` are present in the build context.
- If running the `ci` stage, execute `docker build` from the Flutter project root, not this directory.

**Tests fail with "No tests found"**
- Verify that your `test/` directory is not excluded in `.dockerignore`.

**Image is too large**
- The base image is ~2.5 GB due to the Flutter SDK. This is normal for Flutter CI images.
- Android/iOS/Web precache is disabled to save space. Add `--android` to `flutter precache` if you need Android builds.

**Permission errors on mounted volumes**
- On Linux, you may need to pass `--user $(id -u):$(id -g)` to `docker run`.

**`set: pipefail: invalid option` or similar errors**
- Shell scripts have Windows CRLF line endings. The Dockerfile strips these automatically via `sed`, but if you modify scripts locally ensure they use LF endings. The `.gitattributes` file enforces this on checkout.
