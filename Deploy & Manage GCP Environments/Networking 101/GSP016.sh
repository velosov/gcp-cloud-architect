#VPCs are global resources, composed of several regional-distributed IP addresses ranges known as subnets (https://cloud.google.com/vpc/docs/subnets)

#2. Create custom network
PROJ_ID=$(gcloud config get-value project)
NETWORK="taw-custom-network"

gcloud compute networks create $NETWORK --project=$PROJ_ID --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional
gcloud compute networks subnets create subnet-us-west1 --project=$PROJ_ID --range=10.0.0.0/16 --stack-type=IPV4_ONLY --network=$NETWORK --region=us-west1
gcloud compute networks subnets create subnet-europe-west4 --project=$PROJ_ID --range=10.1.0.0/16 --stack-type=IPV4_ONLY --network=$NETWORK --region=europe-west4
gcloud compute networks subnets create subnet-us-east1 --project=$PROJ_ID --range=10.2.0.0/16 --stack-type=IPV4_ONLY --network=$NETWORK --region=us-east1

#5. Adding firewall rules
#only the default VPC is created with Firewall rules
#though being in the same network makes it such other resources' routes are known, it is still necessary to create fw rules so traffic is not blocked
#Note: Instance Tags are used by networks and firewalls to apply certain firewall rules to tagged VM instances, and are accessible at application level via server metadata.
gcloud compute --project=$PROJ_ID firewall-rules create nw101-allow-http --direction=INGRESS --priority=1000 --network=$NETWORK --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http
gcloud compute firewall-rules create "nw101-allow-icmp" --allow icmp --network $NETWORK --target-tags rules
gcloud compute firewall-rules create "nw101-allow-internal" --allow tcp:0-65535,udp:0-65535,icmp --network $NETWORK --source-ranges "10.0.0.0/16","10.2.0.0/16","10.1.0.0/16"
gcloud compute firewall-rules create "nw101-allow-ssh" --allow tcp:22 --network $NETWORK --target-tags "ssh"
gcloud compute firewall-rules create "nw101-allow-rdp" --allow tcp:3389 --network $NETWORK

#Additional Routes can be created to send traffic to an instance, a VPN gateway, or default internet gateway. These Routes can be modified to tailor the desired network architecture. Routes and Firewalls work together to ensure your traffic gets where it needs to go.


#6. Connecting to VMs and checking latency
gcloud compute instances create us-test-01 \
--subnet subnet-us-west1 \
--zone us-west1-a \
--machine-type e2-standard-2 \
--tags ssh,http,rules

gcloud compute instances create us-test-02 \
--subnet subnet-europe-west4 \
--zone europe-west4-a \
--machine-type e2-standard-2 \
--tags ssh,http,rules

gcloud compute instances create us-test-03 \
--subnet subnet-us-east1 \
--zone us-east1-b \
--machine-type e2-standard-2 \
--tags ssh,http,rules


#Note: Internal DNS: How is DNS provided for VM instances?
# Each instance has a metadata server that also acts as a DNS resolver for that instance. DNS lookups are performed for instance names. The metadata server itself stores all DNS information for the local network and queries Google's public DNS servers for any addresses outside of the local network.
# An internal fully qualified domain name (FQDN) for an instance looks like this: hostName.[ZONE].c.[PROJECT_ID].internal .
# You can always connect from one instance to another using this FQDN. If you want to connect to an instance using, for example, just hostName, you need information from the internal DNS resolver that is provided as part of Compute Engine.