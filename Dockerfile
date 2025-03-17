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

ENV NODE_OPTIONS="--max-old-space-size=4096"
# Make sure the Next.js standalone output is enabled
ENV NEXT_STANDALONE=true 
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

# set timezone
ENV TZ=UTC
RUN ln -s /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# Copy the entire .next directory instead of specific subdirectories
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# create user for running the application
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000

# Direct command to run Next.js without relying on the start script
CMD ["node", ".next/server/app/server.js"]