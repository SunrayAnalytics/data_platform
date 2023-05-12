aws ec2-instance-connect send-ssh-public-key `
    --ssh-public-key "file://~/.ssh/id_ed25519.pub" `
    --instance-id (terraform output -json | jq ".bastion_instance_id.value") `
    --instance-os-user ec2-user

# TODO Lookup the airbyte instance
aws ec2-instance-connect send-ssh-public-key `
    --ssh-public-key "file://~/.ssh/id_ed25519.pub" `
    --instance-id i-0ee59bac874da86ef `
    --instance-os-user ec2-user

ssh -A -J ec2-user@bastion.(terraform output -json | jq ".domain_name" ) ec2-user@10.0.3.184
