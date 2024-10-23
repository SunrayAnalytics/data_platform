# TODO: Somehow connect to bastion automatically based on environment identifier.
aws ec2-instance-connect send-ssh-public-key `
    --ssh-public-key "file://~/.ssh/id_ed25519.pub" `
    --instance-id (terraform output -json | jq ".bastion_instance_id.value")`
    --instance-os-user ec2-user
ssh -Dlocalhost:1080 -L 8000:airbyte.(terraform output -json | jq ".domain_name"):8000 -N ec2-user@bastion.(terraform output -json | jq ".domain_name")
