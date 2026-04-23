import boto3
import os
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    sns = boto3.client('sns')
    
    # Get the SNS Topic from the environment variables we set in Terraform
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    
    sg_id = event['detail']['requestParameters']['groupId']
    items = event['detail']['requestParameters'].get('ipPermissions', {}).get('items', [])

    for item in items:
        port = item.get('fromPort')
        is_forbidden = port in [22, 3389]
        
        ip_ranges = item.get('ipRanges', {}).get('items', [])
        is_open_to_world = any(ip.get('cidrIp') == '0.0.0.0/0' for ip in ip_ranges)

        if is_forbidden and is_open_to_world:
            print(f"CRITICAL: Port {port} opened to world on {sg_id}. Deleting...")
            
            try:
                # 1. Delete the rule
                ec2.revoke_security_group_ingress(
                    GroupId=sg_id,
                    IpPermissions=[{
                        'IpProtocol': item.get('ipProtocol'),
                        'FromPort': port,
                        'ToPort': item.get('toPort'),
                        'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                    }]
                )
                
                # 2. Send the Email Alert
                alert_message = f"🚨 Security Alert! \n\nRule detected: Port {port} was opened to 0.0.0.0/0 on Security Group {sg_id}.\n\nAction: The remediation bot has automatically deleted this rule."
                
                sns.publish(
                    TopicArn=topic_arn,
                    Subject="AWS Security Remediation Alert",
                    Message=alert_message
                )
                print("SUCCESS: Rule removed and notification sent.")
                
            except ClientError as e:
                print(f"ERROR: {e}")
                
    return {'statusCode': 200}