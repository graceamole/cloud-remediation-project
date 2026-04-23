import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    
    sg_id = event['detail']['requestParameters']['groupId']
    items = event['detail']['requestParameters'].get('ipPermissions', {}).get('items', [])

    for item in items:
        # Check for Port 22 or 3389 open to the world
        is_forbidden = item.get('fromPort') in [22, 3389]
        is_open_to_world = any(ip.get('cidrIp') == '0.0.0.0/0' for ip in item.get('ipRanges', {}).get('items', []))

        if is_forbidden and is_open_to_world:
            print(f"CRITICAL: Port {item.get('fromPort')} opened to world on {sg_id}. Deleting...")
            
            try:
                # We RE-MAP the keys to match exactly what Boto3 expects (PascalCase)
                ec2.revoke_security_group_ingress(
                    GroupId=sg_id,
                    IpPermissions=[{
                        'IpProtocol': item.get('ipProtocol'),
                        'FromPort': item.get('fromPort'),
                        'ToPort': item.get('toPort'),
                        'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                    }]
                )
                print("SUCCESS: Rule removed.")
            except ClientError as e:
                print(f"ERROR: {e}")
                
    return {'statusCode': 200}