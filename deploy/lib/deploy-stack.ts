import * as path from 'path'

import { Stack, StackProps } from 'aws-cdk-lib'
import * as ec2 from 'aws-cdk-lib/aws-ec2'
import * as ecs from 'aws-cdk-lib/aws-ecs'
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns'
import { Construct } from 'constructs'

export class DeployStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props)

    const vpc = new ec2.Vpc(this, `${id}-vpc`, {
      maxAzs: 2,
    })

    const cluster = new ecs.Cluster(this, `${id}-cluster`, {
      vpc: vpc,
    })

    const projDir = path.resolve(__dirname, '../..')
    console.log('********************** ', projDir)
    const image = ecs.ContainerImage.fromAsset(projDir, {
      target: 'api_serve',
    })

    // eslint-disable-next-line no-new
    new ecsPatterns.ApplicationLoadBalancedFargateService(
      this,
      `${id}-service`,
      {
        cluster: cluster,
        cpu: 512,
        desiredCount: 1,
        taskImageOptions: { image: image },
        memoryLimitMiB: 2048,
        publicLoadBalancer: true,
      }
    )
  }
}
