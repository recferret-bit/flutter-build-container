# =============================================================================
# Flutter CI/CD Build Container
# =============================================================================
# Reusable Docker image for running Flutter tests, static analysis, and builds
# in cloud CI/CD pipelines (GitHub Actions, GCP Cloud Build, GitLab CI, etc.).
#
# Build:  docker build -t flutter-ci .
# Run:    docker run --rm -v <project-path>:/app flutter-ci
# =============================================================================

FROM ubuntu:22.04 AS base

LABEL maintainer="SyndicateGame"
LABEL description="Flutter CI/CD build container for Survival Syndicate"

# ---------------------------------------------------------------------------
# Build arguments
# ---------------------------------------------------------------------------
ARG FLUTTER_CHANNEL=stable
ARG FLUTTER_VERSION=3.41.1

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/opt/flutter \
    PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}" \
    PUB_CACHE=/opt/pub-cache \
    CI=true

# ---------------------------------------------------------------------------
# System dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        clang \
        cmake \
        ninja-build \
        pkg-config \
        libgtk-3-dev \
        liblzma-dev \
        libstdc++-12-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Install Flutter SDK
# ---------------------------------------------------------------------------
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
        https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter precache --no-android --no-ios --no-web \
    && flutter config --no-analytics \
    && dart --disable-analytics \
    && flutter doctor -v

# ---------------------------------------------------------------------------
# Bake CI scripts into the image
# ---------------------------------------------------------------------------
COPY scripts/ /opt/scripts/
RUN sed -i 's/\r$//' /opt/scripts/*.sh \
    && chmod +x /opt/scripts/*.sh

# ---------------------------------------------------------------------------
# CI stage — copies source and runs the full pipeline
# ---------------------------------------------------------------------------
FROM base AS ci

WORKDIR /app

# Copy dependency manifests first for layer caching
COPY pubspec.yaml pubspec.lock analysis_options.yaml ./

# Resolve dependencies (cached unless pubspec files change)
RUN flutter pub get

# Copy the rest of the project
COPY . .

# Generate code (build_runner)
RUN dart run build_runner build --delete-conflicting-outputs

# Run static analysis
RUN flutter analyze --no-fatal-infos

# Run Dart format check
RUN dart format --set-exit-if-changed .

# Run unit & widget tests
RUN flutter test --coverage --reporter=expanded

# Default command — print summary
CMD ["flutter", "doctor", "-v"]
