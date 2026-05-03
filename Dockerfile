# Build stage
FROM gradle:8.7-jdk21@sha256:2a2fae1da44489e9e0e4d06343c19dce1e0d8198e04d141e7a2e8735e1e1e4e0 AS build
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY src ./src
RUN gradle bootJar --no-daemon -x test

# Runtime stage
FROM gcr.io/distroless/java21-debian12:nonroot@sha256:b2e4b34e4f2a93f7a6f327c55aee7ef674f8a2c3d5e6f7a8b9c0d1e2f3a4b5c6
WORKDIR /app

COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD ["java", "-cp", "app.jar", "org.springframework.boot.loader.launch.JarLauncher", "--server.port=8080"]

ENTRYPOINT ["java", "-jar", "app.jar"]
