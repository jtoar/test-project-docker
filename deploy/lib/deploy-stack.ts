import { Stack, StackProps } from 'aws-cdk-lib'
import * as ec2 from 'aws-cdk-lib/aws-ec2'
import * as ecs from 'aws-cdk-lib/aws-ecs'
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns'
import { Construct } from 'constructs'

export class DeployStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props)

    const projectName = 'RedWoodBlog'

    const vpc = new ec2.Vpc(this, projectName, {
      maxAzs: 1,
    })

    const cluster = new ecs.Cluster(this, projectName, {
      vpc: vpc,
    })

    // eslint-disable-next-line no-new
    new ecsPatterns.ApplicationLoadBalancedFargateService(this, projectName, {
      cluster: cluster,
      cpu: 512,
      desiredCount: 1,
      taskImageOptions: {
        image: ecs.ContainerImage.fromRegistry('amazon/amazon-ecs-sample'),
      },
      memoryLimitMiB: 2048,
      publicLoadBalancer: true,
    })
  }
}
