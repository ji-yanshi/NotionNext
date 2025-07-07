ARG NOTION_PAGE_ID
ARG NEXT_PUBLIC_THEME

FROM node:20-alpine AS base

# 1. Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json ./

# !!! 修复：启用 Corepack 并使用 pnpm 安装依赖 !!!
RUN corepack enable && pnpm install --frozen-lockfile

# 2. Rebuild the source code only when needed
FROM base AS builder
ARG NOTION_PAGE_ID
ENV NEXT_BUILD_STANDALONE=true

WORKDIR /app

# 注意：如果 pnpm 安装的 node_modules 结构与 yarn 不同，可能需要调整 COPY 路径
# 通常 pnpm 会在项目根目录创建 node_modules/.pnpm，但标准情况下仍然是 node_modules
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build # 如果项目使用 pnpm，这里也可能需要改为 pnpm build

# 3. Production image, copy all the files and run next
FROM base AS runner
ENV NODE_ENV=production

WORKDIR /app

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# 个人仓库把将配置好的.env.local文件放到项目根目录，可自动使用环境变量
# COPY --from=builder /app/.env.local ./

EXPOSE 3000

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry.
# ENV NEXT_TELEMETRY_DISABLED 1

CMD ["node", "server.js"]
