# JGMW Working Notes
#
# TODO:
# - Set a user
#   - I think node is owned by the node user? Will check the leftlane example
#
# Files often flagged as inefficient:
# - /tmp/v8-compile-cache-...
#   - I think we can remove this, see: https://github.com/nodejs/docker-node/issues/1326
# - /var/cache/debconf/templates
#   - See: https://github.com/debuerreotype/debuerreotype/issues/95
#
# ==================================================

FROM node:18-slim as base

# To stop yarn install from over-logging.
ENV CI=1

RUN apt-get update || : && apt-get install -y \
    python3 \
    build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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

ENV CI=1 \
    NODE_ENV=production

RUN apt-get update || : && apt-get install -y \
    openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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

EXPOSE 8911

CMD [ "node_modules/.bin/rw-server", "api" ]

# serve web
# ------------------------------------------------
FROM node:18-slim as serve_web

ENV CI=1 \
    NODE_ENV=production \
    API_HOST=http://api:8911

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

EXPOSE 8910

CMD "node_modules/.bin/rw-server" "web" "--apiHost" $API_HOST

# serve
# ------------------------------------------------
FROM node:18-slim as serve

ENV CI=1 \
    NODE_ENV=production

RUN apt-get update || : && apt-get install -y \
    openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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
    yarn workspaces focus api web --production

COPY redwood.toml .
COPY graphql.config.js .

COPY --from=api_build /app/api/dist /app/api/dist
COPY --from=api_build /app/api/db /app/api/db
COPY --from=api_build /app/node_modules/.prisma /app/node_modules/.prisma
COPY --from=web_build /app/web/dist /app/web/dist

ENTRYPOINT [ "/bin/bash" ]

# console
# ------------------------------------------------
FROM base as console

RUN apt-get update || : && apt-get install -y \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY api api
COPY web web
COPY scripts scripts
