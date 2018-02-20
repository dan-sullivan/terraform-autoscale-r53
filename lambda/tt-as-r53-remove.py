import boto3
import logging
import json

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
        # Find Route53 Record (Required incase manual termination means public IP isnt sent)
        records = r53.list_resource_record_sets(StartRecordName="web.tt.internal.", HostedZoneId=r53_zone)["ResourceRecordSets"]
        for record in records:
            logger.info(record["SetIdentifier"])
            if message["EC2InstanceId"] in record["SetIdentifier"]:
                hc_id = record["HealthCheckId"]
                ip = record["ResourceRecords"][0]["Value"]

        # Delete Route53 record
        r53.change_resource_record_sets(
            HostedZoneId=r53_zone,
            ChangeBatch={
            'Changes': [
                {
                    'Action': 'DELETE',
                    'ResourceRecordSet': {
                    'Name': "web.tt.internal.",
                    'Type': 'A',
                    'Weight': 10,
                    'SetIdentifier': 'web-tt ' + message["EC2InstanceId"],
                    'ResourceRecords': [
                    {
                        'Value': ip
                    }
                    ],
                    'HealthCheckId': hc_id,
                    'TTL': 60
                }
                }
            ]
            }
        )

        r53.delete_health_check(HealthCheckId=hc_id)

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
