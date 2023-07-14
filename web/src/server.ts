import path from 'path'

import httpProxy from '@fastify/http-proxy'
import chalk from 'chalk'
import { config } from 'dotenv-defaults'
import Fastify from 'fastify'

import {
  DEFAULT_REDWOOD_FASTIFY_CONFIG,
  coerceRootPath,
} from '@redwoodjs/fastify-shared'
import { redwoodFastifyWeb } from '@redwoodjs/fastify-web'
import { getPaths, getConfig } from '@redwoodjs/project-config'

async function serve() {
  const redwoodProjectPaths = getPaths()
  const redwoodConfig = getConfig()

  const tsServer = Date.now()

  config({
    path: path.join(redwoodProjectPaths.base, '.env'),
    defaults: path.join(redwoodProjectPaths.base, '.env.defaults'),
    multiline: true,
  })

  console.log(chalk.italic.dim('Starting Web Server...'))

  const fastify = Fastify({
    ...DEFAULT_REDWOOD_FASTIFY_CONFIG,
  })

  await fastify.register(redwoodFastifyWeb)

  fastify.register(httpProxy, {
    upstream: `http://${redwoodConfig.api.host}:${redwoodConfig.api.port}`,
    prefix: coerceRootPath(redwoodConfig.web.apiUrl),
    disableCache: true,
  })

  fastify.listen({ port: redwoodConfig.web.port })

  fastify.ready(() => {
    console.log(chalk.italic.dim('Took ' + (Date.now() - tsServer) + ' ms'))
    console.log('Web')
  })

  process.on('exit', () => {
    fastify.close()
  })
}

serve()
