output "ec2_instances" {
  value = {for name, instance in aws_instance.ec2_instances : name => {
    public_ip = instance.public_ip,
    az = instance.availability_zone,
  }}
}

output "ec2_instances_ips" {
  value = {for name, instance in aws_instance.ec2_instances : name =>  instance.public_ip}
}

output "ec2_instances_azs" {
  value = {for name, instance in aws_instance.ec2_instances : name =>  instance.availability_zone }
}

output "ssh_private_key" {
  value = tls_private_key.ssh_key.private_key_pem
}
