# base image
FROM node:20-alpine3.20 AS base
LABEL maintainer="takatost@gmail.com"

# Install required packages
RUN apk add --no-cache tzdata bash
RUN npm install -g pnpm@9.12.2 pm2 cross-env
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# install dependencies
FROM base AS deps
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
# Install dependencies and explicitly add code-inspector-plugin
RUN pnpm install --frozen-lockfile && \
    pnpm add code-inspector-plugin cross-env

# build application
FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Next.js application with standalone output
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm build

# production image
FROM base AS runner
WORKDIR /app

# Environment variables
ENV NODE_ENV=production
ENV EDITION=SELF_HOSTED
ENV DEPLOY_ENV=PRODUCTION
ENV CONSOLE_API_URL=${CONSOLE_API_URL:-http://localhost:5001}
ENV APP_API_URL=${APP_API_URL:-http://localhost:5001}
ENV MARKETPLACE_API_URL=${MARKETPLACE_API_URL:-http://localhost:5001}
ENV MARKETPLACE_URL=${MARKETPLACE_URL:-http://localhost:5001}
ENV PORT=3000
ENV NEXT_TELEMETRY_DISABLED=1
ENV PM2_INSTANCES=2

# set timezone
ENV TZ=UTC
RUN ln -s /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# Copy package files and install dependencies including code-inspector-plugin and cross-env
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile && \
    pnpm add code-inspector-plugin cross-env

# Copy necessary files for production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Create a simple startup script with environment variables that doesn't use cross-env
RUN echo '#!/bin/bash\n\
export NEXT_PUBLIC_DEPLOY_ENV=${DEPLOY_ENV}\n\
export NEXT_PUBLIC_EDITION=${EDITION}\n\
export NEXT_PUBLIC_API_PREFIX=${CONSOLE_API_URL}/console/api\n\
export NEXT_PUBLIC_PUBLIC_API_PREFIX=${APP_API_URL}/api\n\
export NEXT_PUBLIC_MARKETPLACE_API_PREFIX=${MARKETPLACE_API_URL}/api/v1\n\
export NEXT_PUBLIC_MARKETPLACE_URL_PREFIX=${MARKETPLACE_URL}\n\
export NEXT_PUBLIC_SENTRY_DSN=${SENTRY_DSN}\n\
export NEXT_PUBLIC_SITE_ABOUT=${SITE_ABOUT}\n\
export NEXT_PUBLIC_TEXT_GENERATION_TIMEOUT_MS=${TEXT_GENERATION_TIMEOUT_MS}\n\
export NEXT_PUBLIC_CSP_WHITELIST=${CSP_WHITELIST}\n\
export NEXT_PUBLIC_TOP_K_MAX_VALUE=${TOP_K_MAX_VALUE}\n\
export NEXT_PUBLIC_INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH=${INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH}\n\
\n\
# Run the app directly without relying on npm scripts\n\
exec node server.js\n' > ./start.sh && \
    chmod +x ./start.sh

# Setup proper permissions
RUN chown -R 1001:0 /app && \
    chmod -R g=u /app

USER 1001
EXPOSE 3000

# Run using our startup script
CMD ["./start.sh"]