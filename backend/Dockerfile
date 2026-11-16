# Pin backend, for deployment. Build from this folder:
#
#   docker build -t pin-backend .
#
# Or run it with its database: see compose.prod.yaml and "Deploying with Docker" in README.md.

# --- Build: the jar, without the demo data (src/dev) and without running the tests, which need
# Docker themselves. Run them before building the image: mvnw test.
FROM eclipse-temurin:21-jdk AS build
WORKDIR /build
COPY .mvn .mvn
COPY mvnw pom.xml ./
COPY src src
# The cache mount keeps downloaded libraries between builds, so only the first build is slow.
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw -B -q package '-P!demo-data' -Dmaven.test.skip=true

# --- Run: a JRE only, as a user that owns nothing.
FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10001 --no-create-home pin
WORKDIR /app
COPY --from=build --chown=pin:pin /build/target/pin-backend-*.jar app.jar
USER pin

# "prod" makes DevSwitchesGuard refuse to start if a development setting (the dev sign-in code,
# the admin password reset, the demo data) is on by mistake. The JVM sizes its heap from the
# container's memory limit, and exits on running out of memory so Docker restarts it cleanly.
# Headless: the server has no screen; it only needs Java's image classes to resize event pictures.
ENV SPRING_PROFILES_ACTIVE=prod \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -Djava.awt.headless=true"

EXPOSE 8080

# Every endpoint needs a sign-in, so there is nothing to call: this checks that the server is
# listening. The database is checked when it starts (it will not start without it).
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080' || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
