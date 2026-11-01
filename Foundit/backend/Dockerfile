FROM node:22-bookworm-slim AS build

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
# 不執行相依套件的安裝腳本：sharp 用預先編好的二進位檔，不需要；也擋掉惡意 postinstall 與遙測回報。
RUN npm ci --ignore-scripts

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates gosu \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV NODE_ENV=production

COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/package.json ./package.json
COPY deploy/scripts/entrypoint.sh /entrypoint.sh

RUN chmod 755 /entrypoint.sh \
  && mkdir -p /app/uploads \
  && chown node:node /app /app/uploads

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
