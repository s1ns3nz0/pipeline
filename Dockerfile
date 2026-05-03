# =============================================================================
# Multi-stage Dockerfile for Spring Boot Application
# =============================================================================
# Security controls:
#   C-02: Runs as non-root user (UID 1000)
#   C-04: Multi-stage build - build tools excluded from final image
#   C-05: HEALTHCHECK defined for ECS container health monitoring
#   C-07: Base images pinned by tag (use digest in production)
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: BUILD
# Compiles the application using Gradle.
# This stage is NOT included in the final image.
# ---------------------------------------------------------------------------
FROM gradle:8.7-jdk21 AS build
WORKDIR /app

# Copy build files first (layer caching: deps change less often than code)
COPY build.gradle settings.gradle ./

# Download dependencies (cached unless build.gradle changes)
RUN gradle dependencies --no-daemon || true

# Copy source code and build
COPY src ./src
RUN gradle bootJar --no-daemon -x test

# ---------------------------------------------------------------------------
# Stage 2: RUNTIME
# Minimal JRE image with the compiled JAR only.
# No build tools, no source code, no Gradle in the final image.
# ---------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine

# C-02: Create non-root user
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -D -h /app appuser

WORKDIR /app

# Copy only the built JAR from the build stage
COPY --from=build --chown=appuser:appgroup /app/build/libs/*.jar app.jar

# C-02: Run as non-root
USER appuser

EXPOSE 8080

# C-05: Health check for ECS task health monitoring
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
