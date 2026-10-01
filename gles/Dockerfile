# syntax=docker/dockerfile:1
# Builds the standalone GLES reproducer, not the MapLibre SDK or an emulator.
FROM debian:bookworm-slim AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

# Official repository2-1.xml checksum for ndk;28.1.13356709 (Linux).
RUN curl --fail --location --retry 3 \
      https://dl.google.com/android/repository/android-ndk-r28b-linux.zip \
      --output /tmp/ndk.zip \
    && echo 'f574d3165405bd59ffc5edaadac02689075a729f  /tmp/ndk.zip' | sha1sum --check - \
    && unzip -q /tmp/ndk.zip -d /opt \
    && rm /tmp/ndk.zip

ENV ANDROID_NDK_HOME=/opt/android-ndk-r28b
WORKDIR /repro
ARG ANDROID_ABI=x86_64
ENV ANDROID_ABI=${ANDROID_ABI}
COPY vao-repro.cpp build-repro.sh ./
# Also supports Windows checkouts with CRLF shell scripts.
RUN sed -i 's/\r$//' build-repro.sh \
    && bash build-repro.sh \
    && mkdir /out \
    && cp vao-repro /out/vao-repro

FROM scratch AS export
COPY --from=build /out/ /
