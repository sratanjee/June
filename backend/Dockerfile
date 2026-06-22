# syntax=docker/dockerfile:1.7
# Multi-stage build for june-backend.
# Stage 1: install all deps + compile TS → dist/
# Stage 2: slim runtime image with prod deps only.

FROM node:22-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --include=dev
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080
# loadSystemPrompt resolves SPEC_PATH first; pin it to the bundled spec
# so we don't rely on relative path arithmetic from dist/.
ENV SPEC_PATH=/app/June_Personality_Spec.md

# Pull in curl (used by the cron entry to POST localhost) and supercronic
# (small Go cron daemon, ~5MB, that runs alongside Node in the same container).
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG SUPERCRONIC_VERSION=v0.2.29
ARG SUPERCRONIC_SHA1=cd48d45c4b10f3f0bfdd3a57d054cd05ac96812b
ADD https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN echo "${SUPERCRONIC_SHA1}  /usr/local/bin/supercronic" | sha1sum -c - \
 && chmod +x /usr/local/bin/supercronic

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY June_Personality_Spec.md ./June_Personality_Spec.md
COPY crontab /app/crontab
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 8080
CMD ["/app/start.sh"]
