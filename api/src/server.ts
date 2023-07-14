import path from 'path'

import chalk from 'chalk'
import { config } from 'dotenv-defaults'
import Fastify from 'fastify'

import { redwoodFastifyAPI } from '@redwoodjs/fastify-functions'
import { redwoodFastifyGraphQLServer } from '@redwoodjs/fastify-graphql'
import { DEFAULT_REDWOOD_FASTIFY_CONFIG } from '@redwoodjs/fastify-shared'
import { getPaths, getConfig } from '@redwoodjs/project-config'

import directives from 'src/directives/**/*.{js,ts}'
import sdls from 'src/graphql/**/*.sdl.{js,ts}'
import services from 'src/services/**/*.{js,ts}'

// Import if using RedwoodJS authentication
// import { authDecoder } from '@redwoodjs/<your-auth-provider>'
// import { getCurrentUser } from 'src/lib/auth'

import { logger } from 'src/lib/logger'

// Import if using RedwoodJS Realtime via `yarn rw exp setup-realtime`
// import { realtime } from 'src/lib/realtime'

async function serve() {
  // Load .env files
  const redwoodProjectPaths = getPaths()
  const redwoodConfig = getConfig()

  const port = redwoodConfig.api.port

  const tsServer = Date.now()

  config({
    path: path.join(redwoodProjectPaths.base, '.env'),
    defaults: path.join(redwoodProjectPaths.base, '.env.defaults'),
    multiline: true,
  })

  console.log(chalk.italic.dim('Starting API Server...'))

  // Configure Fastify
  const fastify = Fastify({
    ...DEFAULT_REDWOOD_FASTIFY_CONFIG,
  })

  await fastify.register(redwoodFastifyAPI, {
    redwood: {},
  })

  await fastify.register(redwoodFastifyGraphQLServer, {
    // If authenticating, be sure to import and add in
    // authDecoder,
    // getCurrentUser,
    loggerConfig: {
      logger: logger,
    },
    graphiQLEndpoint: '/graphql',
    sdls,
    services,
    directives,
    allowIntrospection: true,
    allowGraphiQL: true,
    // Configure if using RedwoodJS Realtime
    // realtime,
  })

  // Start
  fastify.listen({ port })

  fastify.ready(() => {
    console.log(chalk.italic.dim('Took ' + (Date.now() - tsServer) + ' ms'))
    const apiServer = chalk.magenta(`http://localhost:${port}`)
    console.log(`API serving from ${apiServer}`)
  })

  process.on('exit', () => {
    fastify.close()
  })
}

serve()
