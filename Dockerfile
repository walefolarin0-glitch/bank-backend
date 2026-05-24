# ── Stage 1: Build Stage ─────────────────────────────────────────────────────
# Pull the official Maven image with Eclipse Temurin JDK 17 on Alpine Linux
# This image has both Maven and JDK 17 — everything needed to compile the app
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

# Set /app as the working directory inside the build container
# All subsequent commands will run from this directory
WORKDIR /app

# Copy only pom.xml first (before source code)
# This is a Docker layer caching trick — if pom.xml hasn't changed,
# Docker skips the next RUN step and reuses the cached dependencies layer
COPY pom.xml /app/pom.xml

# Download all Maven dependencies declared in pom.xml into the container
# --offline flag in later steps works because all deps are already cached here
# This dramatically speeds up repeat builds
RUN mvn dependency:go-offline

# Copy the entire src folder into the container's /app/src directory
# Done after dependency download so code changes don't invalidate the deps cache
COPY src ./src

# Compile the source code and package it into a .jar file
# -DskipTests skips running unit tests during the build (faster CI builds)
# Output .jar is saved to /app/target/
RUN mvn clean package -DskipTests


# ── Stage 2: Run Stage ────────────────────────────────────────────────────────
# Pull a much smaller base image — only the JRE (Java Runtime Environment)
# JRE = runs Java apps | JDK = compiles Java apps (not needed at runtime)
# Alpine variant keeps the image lightweight (~190MB vs ~400MB)
# Maven and source code from Stage 1 are completely discarded here
FROM eclipse-temurin:17-jre-alpine

# Set /app as the working directory inside the final container
WORKDIR /app

# Copy ONLY the compiled .jar from Stage 1 (builder) into this final image
# Nothing else from Stage 1 comes across — no Maven, no source code, no JDK
# This is the key security and size benefit of multi-stage builds
COPY --from=builder /app/target/*.jar app.jar

# Define the command that runs when the container starts
CMD ["java", "-jar", "app.jar"]