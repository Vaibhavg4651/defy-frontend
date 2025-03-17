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
RUN pnpm install --frozen-lockfile && \
    pnpm add code-inspector-plugin

# build application
FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Next.js application
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm build

# production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV EDITION=SELF_HOSTED
ENV DEPLOY_ENV=PRODUCTION
ENV CONSOLE_API_URL=http://localhost:5001
ENV APP_API_URL=http://localhost:5001
ENV MARKETPLACE_API_URL=http://localhost:5001
ENV MARKETPLACE_URL=http://localhost:5001
ENV PORT=3000
ENV NEXT_TELEMETRY_DISABLED=1
ENV PM2_INSTANCES=2

# set timezone
ENV TZ=UTC
RUN ln -s /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# Install only production dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile && \
    pnpm add code-inspector-plugin

# Copy built application and necessary files
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./next.config.js

# create user for running the application
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000

# Directly use next start command without a separate script
CMD ["pnpm", "dev"]