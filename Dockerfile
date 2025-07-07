ARG NOTION_PAGE_ID
ARG NEXT_PUBLIC_THEME

FROM node:20-alpine AS base

# ✅ 安装构建工具和 pnpm（全局方式更稳定）
RUN apk add --no-cache libc6-compat build-base python3 \
    && npm install -g pnpm

WORKDIR /app

# 1. Install dependencies only when needed
FROM base AS deps
COPY package.json ./

# !!! 修复：由于 ERR_PNPM_LOCKFILE_CONFIG_MISMATCH 错误，暂时移除 --frozen-lockfile
RUN pnpm install

# 2. Rebuild the source code only when needed
FROM base AS builder
ARG NOTION_PAGE_ID
ENV NEXT_BUILD_STANDALONE=true

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# ✅ 使用全局安装的 pnpm 构建
RUN pnpm build

# 3. Production image, copy all the files and run next
FROM base AS runner
ENV NODE_ENV=production

WORKDIR /app

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# 若使用本地环境变量文件
# COPY --from=builder /app/.env.local ./

EXPOSE 3000

# 禁用 Next.js 远程收集（可选）
# ENV NEXT_TELEMETRY_DISABLED 1

CMD ["node", "server.js"]
