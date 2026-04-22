import boto3

def lambda_handler(event, context):
    # 1. Connect to the EC2 service (The Network Tools)
    ec2 = boto3.client('ec2')
    
    # 2. Extract the Security Group ID from the EventBridge message
    sg_id = event['detail']['requestParameters']['groupId']
    
    # 3. Pull out the details of the new rule being added
    # This finds out which "door" (port) someone tried to open
    items = event['detail']['requestParameters'].get('ipPermissions', {}).get('items', [])

    for item in items:
        # 4. Check if the door is Port 22 (SSH) and if it's open to the whole world (0.0.0.0/0)
        if item.get('fromPort') == 22 and '0.0.0.0/0' in [ip.get('cidrIp') for ip in item.get('ipRanges', {}).get('items', [])]:
            print(f"CRITICAL: Port 22 opened to the world on {sg_id}. Deleting rule...")
            
            # 5. The Muscle: This command deletes the rule immediately
            ec2.revoke_security_group_ingress(
                GroupId=sg_id,
                IpPermissions=[item]
            )
            print("SUCCESS: Rule removed.")
            
    return {
        'statusCode': 200,
        'body': 'Security check complete.'
    }