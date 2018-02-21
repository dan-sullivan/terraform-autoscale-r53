import boto3
import logging
import json
import uuid

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

def handler(event, context):
    if event == "cli":
        logger.info("Command Line Invoked")
    else:
        logger.info(json.dumps(event))
        asg = boto3.client('autoscaling')
        r53 = boto3.client('route53')
        ec2 = boto3.resource('ec2')

        # Get the SNS message data into a dict
        message = json.loads(event["Records"][0]["Sns"]["Message"])
        logger.info(message)

        # Get the custom notification data into a dict and assign to vars
        notification_meta = json.loads(message["NotificationMetadata"])
        r53_zone = notification_meta["r53_zone"]

    try:
        instance = ec2.Instance(message["EC2InstanceId"])
        logger.info(instance.public_ip_address)

        # Generate a unique key for caller reference
        callref = str(uuid.uuid1())
        logger.info(callref)
        response = r53.create_health_check(
            CallerReference=callref,
            HealthCheckConfig={
                'IPAddress': instance.public_ip_address,
                'Port': 80,
                'Type': 'HTTP',
                'ResourcePath': '/',
                'RequestInterval': 10,
                'FailureThreshold': 3,
            }
        )

        hc_id = response[u'HealthCheck']["Id"]

        # Create a new Route53 record
        r53.change_resource_record_sets(
            HostedZoneId=r53_zone,
            ChangeBatch={
            'Changes': [
                {
                    'Action': 'CREATE',
                    'ResourceRecordSet': {
                    'Name': "web.tt.internal.",
                    'Type': 'A',
                    'Weight': 10,
                    'SetIdentifier': 'web-tt ' + message["EC2InstanceId"],
                    'ResourceRecords': [
                    {
                        'Value': instance.public_ip_address
                    }
                    ],
                    'HealthCheckId': hc_id,
                    'TTL': 60
                }
                }
            ]
            }
        )


        response = asg.complete_lifecycle_action(
            LifecycleHookName=message["LifecycleHookName"],
            LifecycleActionToken=message["LifecycleActionToken"],
            AutoScalingGroupName="tt-as-group-instance",
            LifecycleActionResult="CONTINUE",
            InstanceId=message["EC2InstanceId"]
            )
        logger.info(response)
    except Exception as e:
        logger.error("Error: %s", str(e))

if __name__ == '__main__':
    print(handler("cli", ""))
