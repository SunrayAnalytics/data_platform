#!/bin/bash
# --ssh-public-key "file://${HOME}/.ssh/id_ecdsa_sk.pub" \
set -x -e
# TODO: Somehow connect to bastion automatically based on environment identifier.
aws ec2-instance-connect send-ssh-public-key \
    --ssh-public-key "file://${HOME}/.ssh/id_ed25519.pub" \
    --instance-id $(terraform output -json | jq -r ".bastion_instance_id.value") \
    --instance-os-user ec2-user
#ssh -Dlocalhost:1080  -L 8000:airbyte.$(terraform output -json | jq -r ".domain_name.value"):8000 -N ec2-user@bastion.$(terraform output -json | jq -r ".domain_name.value")
ssh ec2-user@bastion.$(terraform output -json | jq -r ".domain_name.value")
