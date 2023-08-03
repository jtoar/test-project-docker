# base
# ------------------------------------------------
FROM node:18-bookworm-slim as base

# To stop yarn install from over-logging.
ENV CI=1

RUN apt-get update || : && apt-get install -y \
    python3 \
    build-essential \
    openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN yarn cache clean

WORKDIR /home/node/app
RUN chown -R node:node /home/node/app
USER node

COPY --chown=node:node .yarn/releases .yarn/releases
COPY --chown=node:node .yarnrc.yml .yarnrc.yml
COPY --chown=node:node .yarn/plugins .yarn/plugins
COPY --chown=node:node package.json package.json
COPY --chown=node:node api/package.json api/package.json
COPY --chown=node:node web/package.json web/package.json
COPY --chown=node:node yarn.lock yarn.lock

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,uid=1000 \
    --mount=type=cache,target=/home/node/.cache,uid=1000 \
    yarn install --immutable --inline-builds

RUN yarn cache clean

COPY --chown=node:node redwood.toml .
COPY --chown=node:node graphql.config.js .

# api build
# ------------------------------------------------
FROM base as api_build

COPY --chown=node:node api api
RUN node_modules/.bin/redwood build api

# web prerender build
# ------------------------------------------------
FROM api_build as web_build_with_prerender

COPY --chown=noe:node web web
RUN node_modules/.bin/redwood build web

# web build
# ------------------------------------------------
FROM base as web_build

COPY --chown=node:node web web
RUN node_modules/.bin/redwood build web --no-prerender

# serve api
# ------------------------------------------------
FROM node:18-bookworm-slim as api_serve

ENV CI=1 \
    NODE_ENV=production

RUN apt-get update || : && apt-get install -y \
    openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /home/node/app
RUN chown -R node:node /home/node/app
USER node

COPY --chown=node:node .yarn/releases .yarn/releases
COPY --chown=node:node .yarnrc.yml .yarnrc.yml
COPY --chown=node:node .yarn/plugins .yarn/plugins
COPY --chown=node:node api/package.json .
COPY --chown=node:node yarn.lock yarn.lock

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,uid=1000 \
    --mount=type=cache,target=/home/node/.cache,uid=1000 \
    yarn workspaces focus api --production

RUN yarn cache clean

COPY --chown=node:node redwood.toml .
COPY --chown=node:node graphql.config.js .

COPY --chown=node:node --from=api_build /home/node/app/api/dist /home/node/app/api/dist
COPY --chown=node:node --from=api_build /home/node/app/api/db /home/node/app/api/db
COPY --chown=node:node --from=api_build /home/node/app/node_modules/.prisma /home/node/app/node_modules/.prisma

CMD [ "node_modules/.bin/rw-server", "api" ]

# serve web
# ------------------------------------------------
FROM node:18-bookworm-slim as web_serve

ENV CI=1 \
    NODE_ENV=production \
    API_HOST=http://api:8911

WORKDIR /home/node/app
RUN chown -R node:node /home/node/app
USER node

COPY --chown=node:node .yarn/releases .yarn/releases
COPY --chown=node:node .yarnrc.yml .yarnrc.yml
COPY --chown=node:node .yarn/plugins .yarn/plugins
COPY --chown=node:node web/package.json .
COPY --chown=node:node yarn.lock yarn.lock

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,uid=1000 \
    --mount=type=cache,target=/home/node/.cache,uid=1000 \
    yarn workspaces focus web --production

RUN yarn cache clean

COPY --chown=node:node redwood.toml .
COPY --chown=node:node graphql.config.js .

COPY --chown=node:node --from=web_build /home/node/app/web/dist /home/node/app/web/dist

# Shell form is used to allow for variable substitution
CMD "node_modules/.bin/rw-server" "web" "--apiHost" "$API_HOST"

# console
# ------------------------------------------------
FROM base as console

# If you want to add any development packages, you'll need to do the following:
#
# ```
# USER root
#
# RUN apt-get update || : && apt-get install -y \
#     curl
#
# USER node
# ```

COPY --chown=node:node api api
COPY --chown=node:node web web
COPY --chown=node:node scripts scripts

