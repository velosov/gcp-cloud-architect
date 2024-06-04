gcloud compute instances create privatenet-us-vm --zone= --machine-type=e2-micro --subnet=privatesubnet-us

gcloud compute instances list --sort-by=ZONE

gcloud compute instances create vm-appliance \
    --project=qwiklabs-gcp-02-a3e367782ce6 \
    --zone=us-west1-c \
    --machine-type=e2-standard-4 \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=privatesubnet-us \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=managementsubnet-us \
    --metadata=enable-oslogin=true \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=222773926520-compute@developer.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --create-disk=auto-delete=yes,boot=yes,device-name=vm-appliance,image=projects/debian-cloud/global/images/debian-12-bookworm-v20240515,mode=rw,size=10,type=projects/qwiklabs-gcp-02-a3e367782ce6/zones/us-west1-c/diskTypes/pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any

gcloud compute ssh --zone "us-west1-c" "privatenet-us-vm" --project "qwiklabs-gcp-02-a3e367782ce6"

sudo ifconfig

ping -c 3 'mynet-eu-vm'
#Note: This does not work! In a multiple interface instance, every interface gets a route for the subnet that it is in. In addition, the instance gets a single default route that is associated with the primary interface eth0. Unless manually configured otherwise, any traffic leaving an instance for any destination other than a directly connected subnet will leave the instance via the default route on eth0.

ip route
#Note: The primary interface eth0 gets the default route (default via 172.16.0.1 dev eth0), and all three interfaces eth0, eth1 and eth2 get routes for their respective subnets. Since, the subnet of mynet-eu-vm (10.132.0.0/20) is not included in this routing table, the ping to that instance leaves vm-appliance on eth0 (which is on a different VPC network). You could change this behavior by configuring policy routing as documented in the Configuring policy routing section of the Google Cloud Guide.