ARG BASE_IMAGE=cimg/android:2026.07.1
FROM ${BASE_IMAGE}
USER root
RUN sdkmanager "platforms;android-36" "build-tools;35.0.0"
ENV GRADLE_USER_HOME=/gradle-cache
ENV ANDROID_USER_HOME=/root/.android
COPY . /opt/repro
RUN sed -i 's/\r$//' /opt/repro/gradlew /opt/repro/docker-build.sh
ENTRYPOINT ["bash", "/opt/repro/docker-build.sh"]
