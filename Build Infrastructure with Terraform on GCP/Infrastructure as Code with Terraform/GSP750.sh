terraform init

terraform plan -out static_ip

terraform apply "static_ip"

terraform show

#necessary to force the instance to be recreated with edited/added provisioner
terraform taint google_compute_instance.vm_instance

terraform apply

terraform destroy