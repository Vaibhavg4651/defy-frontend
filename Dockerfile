# base image
FROM node:20-alpine3.20 AS base
LABEL maintainer="takatost@gmail.com"

RUN apk add --no-cache tzdata
RUN npm install -g pnpm@9.12.2
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# install dependencies
FROM base AS deps
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# build application
FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Ensure next.config.js has output: 'standalone' set
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm build

# production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_PUBLIC_EDITION=SELF_HOSTED
ENV NEXT_PUBLIC_DEPLOY_ENV=PRODUCTION
ENV NEXT_PUBLIC_API_PREFIX=${CONSOLE_API_URL:-http://localhost:5001/console/api}
ENV NEXT_PUBLIC_PUBLIC_API_PREFIX=${APP_API_URL:-http://localhost:5001/api}
ENV PORT=3000
ENV NEXT_TELEMETRY_DISABLED=1
ENV HOST=0.0.0.0

# set timezone
ENV TZ=UTC
RUN ln -s /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# Install only production dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --prod --frozen-lockfile

# Copy built application and necessary files
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./

# Create our own simplified start script
RUN echo '#!/bin/sh\nnode_modules/.bin/next start -p ${PORT:-3000} -H ${HOST:-0.0.0.0}' > ./start.sh && \
    chmod +x ./start.sh

# create user for running the application
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000

# Run our custom start script
CMD ["./start.sh"]