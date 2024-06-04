#create the privatenet VPC
gcloud compute networks create privatenet --subnet-mode=custom

#create the privatesubnet-us subnet
gcloud compute networks subnets create privatesubnet-us --network=privatenet --region=US_Region --range=172.16.0.0/24

#create the privatesubnet-eu subnet
gcloud compute networks subnets create privatesubnet-eu --network=privatenet --region=EU_Region --range=172.20.0.0/20

gcloud compute networks list
#Note: default and mynetwork are auto mode networks, whereas, managementnet and privatenet are custom mode networks.
#Auto mode networks create subnets in each region automatically, while custom mode networks start with no subnets, giving you full control over subnet creation

#list the available VPC subnets (sorted by VPC network)
gcloud compute networks subnets list --sort-by=NETWORK

#create the privatenet-allow-icmp-ssh-rdp firewall rule
gcloud compute firewall-rules create privatenet-allow-icmp-ssh-rdp --direction=INGRESS --priority=1000 --network=privatenet --action=ALLOW --rules=icmp,tcp:22,tcp:3389 --source-ranges=0.0.0.0/0
gcloud compute firewall-rules list --sort-by=NETWORK