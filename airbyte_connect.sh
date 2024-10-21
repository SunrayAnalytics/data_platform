#/bin/bash
set -e -x

AIRBYTE_INSTANCE_ID=i-0abaa101252a2e7da
AIRBYTE_INSTANCE_IP=10.0.5.190
aws ec2-instance-connect send-ssh-public-key \
    --ssh-public-key "file://~/.ssh/id_ed25519.pub" \
    --instance-id $(terraform output -json | jq -r ".bastion_instance_id.value") \
    --instance-os-user ec2-user

# TODO Lookup the airbyte instance
aws ec2-instance-connect send-ssh-public-key \
    --ssh-public-key "file://~/.ssh/id_ed25519.pub" \
    --instance-id ${AIRBYTE_INSTANCE_ID} \
    --instance-os-user ec2-user

ssh -A -J ec2-user@bastion.$(terraform output -json | jq -r ".domain_name.value" ) ec2-user@${AIRBYTE_INSTANCE_IP}
