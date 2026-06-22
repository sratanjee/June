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

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY June_Personality_Spec.md ./June_Personality_Spec.md

EXPOSE 8080
CMD ["node", "dist/server.js"]
