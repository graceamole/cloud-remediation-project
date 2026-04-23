import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # Detect the region where the event happened
    region = event.get('region', 'us-east-1')
    ec2 = boto3.client('ec2', region_name=region)
    
    sg_id = event['detail']['requestParameters']['groupId']
    items = event['detail']['requestParameters'].get('ipPermissions', {}).get('items', [])

    for item in items:
        # Check for Port 22 or 3389 open to the world
        is_forbidden = item.get('fromPort') in [22, 3389]
        
        # Check if the rule is open to '0.0.0.0/0'
        ip_ranges = item.get('ipRanges', {}).get('items', [])
        is_open_to_world = any(ip.get('cidrIp') == '0.0.0.0/0' for ip in ip_ranges)

        if is_forbidden and is_open_to_world:
            port = item.get('fromPort')
            print(f"CRITICAL: Port {port} opened to world on {sg_id} in {region}. Deleting...")
            
            try:
                # Re-mapping keys to PascalCase for Boto3
                ec2.revoke_security_group_ingress(
                    GroupId=sg_id,
                    IpPermissions=[{
                        'IpProtocol': item.get('ipProtocol'),
                        'FromPort': item.get('fromPort'),
                        'ToPort': item.get('toPort'),
                        'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                    }]
                )
                print(f"SUCCESS: Rule for Port {port} removed.")
            except ClientError as e:
                # Idempotency: If someone else deleted it first, don't crash!
                if e.response['Error']['Code'] == 'InvalidPermission.NotFound':
                    print(f"INFO: Rule for Port {port} already removed.")
                else:
                    print(f"ERROR: {e}")
                
    return {'statusCode': 200}