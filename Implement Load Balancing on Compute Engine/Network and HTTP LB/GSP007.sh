    1  history
    2  gcloud auth list #list active account name
    3  gcloud config list project #project ID
    4  #1. Set the default region and zone for all resources
    5  gcloud config set compute/region us-west1
    6  gcloud config set compute/zone us-west1-c
    7  #2. Create multiple web server instances
    8  #2.1. Create three Compute Engine VM Apache instances, w/ Firewall rule
    9    gcloud compute instances create www \
    --zone=Zone \
    --tags=network-lb-tag \
    --machine-type=e2-small \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "
      <h3>Web Server: www</h3>" | tee /var/www/html/index.html' && \
      gcloud compute firewall-rules create www-firewall-network-lb     --target-tags network-lb-tag --allow tcp:80
   10  #get the external IP addresses of your instances and verify that they are running
   11  gcloud compute instances list
   13  export ENDPOINT=$(gcloud compute instances list --format="value(networkInterfaces[0].accessConfigs[0].natIP)" | head -n 1)
   14  curl $ENDPOINT
   15  
   16  #3. Configure the load balancing service
   17  gcloud compute addresses create network-lb-ip-1   --region us-west1 #Create a static external IP address for your load balancer
   18  gcloud compute http-health-checks create basic-check #add required HTTP health check
   19  gcloud compute target-pools create www-pool   --region us-west1 --http-health-check basic-check #same-regioned target pool that will serve address
   20  gcloud compute target-pools add-instances www-pool     --instances www1,www2,www3 #add the instances to the pool
   21  gcloud compute forwarding-rules create www-rule     --region  us-west1     --ports 80     --address network-lb-ip-1     --target-pool www-pool #add a forwarding rule
   22  #4. Sending traffic to your instances
   23  gcloud compute forwarding-rules describe www-rule --region us-west1 #view the external IP address of the www-rule forwarding rule used by the load balancer
   24  IPADDRESS=$(gcloud compute forwarding-rules describe www-rule --region us-west1 --format="json" | jq -r .IPAddress) #access the external IP address
   25  echo $IPADDRESS
   26  while true; do curl -m1 $IPADDRESS; done
   27  #5. Create an HTTP load balancer
   28  #   HTTP(S) Load Balancing is implemented on Google Front End (GFE). VMs need to be in an instance group.
   29  gcloud compute instance-templates create lb-backend-template    --region=us-west1    --network=default    --subnet=default    --tags=allow-health-check    --machine-type=e2-medium    --image-family=debian-11    --image-project=debian-cloud    --metadata=startup-script='#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname="$(curl -H "Metadata-Flavor:Google" \
     http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "Page served from: $vm_hostname" | \
     tee /var/www/html/index.html
     systemctl restart apache2'
   30  #   Managed instance groups (MIGs) let you operate apps on multiple identical VMs, leveraging autoscaling, autohealing, regional (multiple zone) deployment, and automatic updating
   31  gcloud compute instance-groups managed create lb-backend-group    --template=lb-backend-template --size=2 --zone=us-west1-c
   32  gcloud compute firewall-rules create fw-allow-health-check   --network=default   --action=allow   --direction=ingress   --source-ranges=130.211.0.0/22,35.191.0.0/16   --target-tags=allow-health-check   --rules=tcp:80 #create firewall rule using target tag allow-health-check to identify the VMs
   33  gcloud compute addresses create lb-ipv4-1   --ip-version=IPV4   --global #sets up the global static external IP address
   34  gcloud compute addresses describe lb-ipv4-1   --format="get(address)"   --global
   35  gcloud compute health-checks create http http-basic-check   --port 80 #load-balancer's health check
   36  gcloud compute backend-services create web-backend-service   --protocol=HTTP   --port-name=http   --health-checks=http-basic-check   --global #creates backend service
   37  gcloud compute backend-services add-backend web-backend-service   --instance-group=lb-backend-group   --instance-group-zone=us-west1-c   --global #add your instance group as the backend to the backend service
   38  #URL map is a Google Cloud configuration resource used to route requests to backend services or backend buckets. For example, with an external HTTP(S) load balancer, you can use a single URL map to route requests to different destinations based on the rules configured in the URL map
   39  gcloud compute url-maps create web-map-http     --default-service web-backend-service
   40  gcloud compute target-http-proxies create http-lb-proxy     --url-map web-map-http #target HTTP proxy to route requests to your URL map
   41  gcloud compute forwarding-rules create http-content-rule    --address=lb-ipv4-1   --global    --target-http-proxy=http-lb-proxy    --ports=80 #global forwarding rule to route incoming requests to the proxy
   42  #A forwarding rule and its corresponding IP address represent the frontend configuration of a Google Cloud load balancer
