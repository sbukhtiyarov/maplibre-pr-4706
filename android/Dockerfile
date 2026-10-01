ARG BASE_IMAGE=cimg/android:2026.07.1
FROM ${BASE_IMAGE}
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 ninja-build git curl util-linux \
    && rm -rf /var/lib/apt/lists/*
RUN sdkmanager "platforms;android-36" "build-tools;35.0.0" "ndk;28.1.13356709" "cmake;3.31.6"
ENV GRADLE_USER_HOME=/gradle-cache
ENV ANDROID_USER_HOME=/root/.android
COPY . /opt/repro
RUN sed -i 's/\r$//' /opt/repro/gradlew /opt/repro/docker-build.sh /opt/repro/native/build.sh
ENTRYPOINT ["bash", "/opt/repro/docker-build.sh"]
