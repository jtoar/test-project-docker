FROM node:18-slim as base

ENV CI=1

RUN apt-get update || : && apt-get install -y \
    python3 \
    build-essential

RUN yarn cache clean

WORKDIR /app

COPY .yarn/releases .yarn/releases
COPY .yarnrc.yml .yarnrc.yml
COPY .yarn/plugins .yarn/plugins
COPY package.json package.json
COPY api/package.json api/package.json
COPY web/package.json web/package.json
COPY yarn.lock yarn.lock

RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    --mount=type=cache,target=/root/.cache \
    yarn install --immutable --inline-builds

COPY redwood.toml .
COPY graphql.config.js .

# api build
# ------------------------------------------------
FROM base as api_build

COPY api api
RUN node_modules/.bin/redwood build api

# web build
# ------------------------------------------------
FROM base as web_build

COPY web web
RUN node_modules/.bin/redwood build web --no-prerender

# web prerender build
# ------------------------------------------------
FROM api_build as web_prerender_build

COPY web web
RUN node_modules/.bin/redwood build web

# serve api
# ------------------------------------------------
FROM node:18-slim as serve_api

ENV CI=1

RUN apt-get update || : && apt-get install -y \
    openssl

ENV NODE_ENV production

WORKDIR /app

COPY .yarn/releases .yarn/releases
COPY .yarnrc.yml .yarnrc.yml
COPY .yarn/plugins .yarn/plugins
COPY api/package.json .
COPY yarn.lock yarn.lock

RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    --mount=type=cache,target=/root/.cache \
    yarn workspaces focus api --production

COPY redwood.toml .
COPY graphql.config.js .

COPY --from=api_build /app/api/dist /app/api/dist
COPY --from=api_build /app/api/db /app/api/db
COPY --from=api_build /app/node_modules/.prisma /app/node_modules/.prisma

CMD [ "node_modules/.bin/rw-server", "api" ]

# serve web
# ------------------------------------------------
FROM node:18-slim as serve_web

ENV CI=1
ENV API_HOST=http://api:8911
ENV NODE_ENV production

WORKDIR /app

COPY .yarn/releases .yarn/releases
COPY .yarnrc.yml .yarnrc.yml
COPY .yarn/plugins .yarn/plugins
COPY web/package.json .
COPY yarn.lock yarn.lock

RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    --mount=type=cache,target=/root/.cache \
    yarn workspaces focus web --production

COPY redwood.toml .
COPY graphql.config.js .

COPY --from=web_build /app/web/dist /app/web/dist

CMD "node_modules/.bin/rw-server" "web" "--apiHost" $API_HOST

# console
# ------------------------------------------------
FROM base as console

RUN apt-get update || : && apt-get install -y \
    curl

COPY api api
COPY web web
COPY scripts scripts
