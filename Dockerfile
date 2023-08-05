# base
# ------------------------------------------------
FROM node:18-bookworm-slim as base

RUN apt-get update && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /home/node/app

COPY --chown=node:node .yarn/plugins .yarn/plugins
COPY --chown=node:node .yarn/releases .yarn/releases
COPY --chown=node:node .yarnrc.yml .
COPY --chown=node:node package.json .
COPY --chown=node:node api/package.json api/
COPY --chown=node:node web/package.json web/
COPY --chown=node:node yarn.lock .

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,uid=1000 \
    --mount=type=cache,target=/home/node/.cache,uid=1000 \
    CI=1 yarn install

COPY --chown=node:node redwood.toml .
COPY --chown=node:node graphql.config.js .

# api build
# ------------------------------------------------
FROM base as api_build

# See https://render.com/docs/docker-secrets#environment-variables-in-docker-builds.
ARG DATABASE_URL

COPY --chown=node:node api api
# See https://community.render.com/t/release-command-for-db-migrations/247/10.
RUN yarn redwood build api \
    && yarn redwood prisma migrate deploy

# serve api
# ------------------------------------------------
FROM node:18-bookworm-slim as api_serve

RUN apt-get update && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /home/node/app

COPY --chown=node:node .yarn/plugins .yarn/plugins
COPY --chown=node:node .yarn/releases .yarn/releases
COPY --chown=node:node .yarnrc.yml .
COPY --chown=node:node api/package.json .
COPY --chown=node:node yarn.lock .

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,uid=1000 \
    --mount=type=cache,target=/home/node/.cache,uid=1000 \
    CI=1 yarn workspaces focus api --production

COPY --chown=node:node redwood.toml .
COPY --chown=node:node graphql.config.js .

COPY --chown=node:node --from=api_build /home/node/app/api/dist /home/node/app/api/dist
COPY --chown=node:node --from=api_build /home/node/app/api/db /home/node/app/api/db
COPY --chown=node:node --from=api_build /home/node/app/node_modules/.prisma /home/node/app/node_modules/.prisma

ENV NODE_ENV=production

CMD [ "node_modules/.bin/rw-server", "api", "--apiRootPath=/" ]

# console
# ------------------------------------------------
FROM base as console

# To add more packages:
#
# ```
# USER root
#
# RUN apt-get update && apt-get install -y \
#     curl
#
# USER node
# ```

COPY --chown=node:node api api
COPY --chown=node:node web web
COPY --chown=node:node scripts scripts
