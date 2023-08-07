#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib'

import { DeployStack } from '../lib/deploy-stack'

const app = new cdk.App()
// eslint-disable-next-line no-new
new DeployStack(app, 'RedwoodBlog')
