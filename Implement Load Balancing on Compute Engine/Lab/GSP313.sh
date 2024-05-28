#0. Set environment
export TEAM=nucleus

export NAME=$TEAM-jumphost-777
export APP=hello
export FIRENAME=accept-tcp-rule-402
export PORT_NO=80
export PORT_NAME=http:$PORT_NO

export INFRA=$TEAM-infra
export REGION=us-east1
export ZONE=us-east1-d
export VPC=$TEAM-vpc

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

#1. Create a project jumphost instance
gcloud compute instances create $NAME --zone=$ZONE --machine-type=e2-micro

#2. Set up an HTTP load balancer
gcloud compute networks create $VPC --subnet-mode=auto

gcloud container clusters create $INFRA \
    --num-nodes=1 \
    --zone=$ZONE

gcloud container clusters get-credentials $INFRA \
          --zone $ZONE

kubectl create deployment $APP \
          --image=gcr.io/google-samples/hello-app:2.0

kubectl expose deployment $APP \
          --type=LoadBalancer \
          --port $PORT_NO

cat << EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y nginx
service nginx start
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
EOF

#Create an instance template. Don't use the default machine type. Make sure you specify e2-medium as the machine type
gcloud compute instance-templates create $TEAM-template --network $VPC --region $REGION --machine-type=e2-medium  --image-family=debian-11    --image-project=debian-cloud  --tags=allow-health-check --metadata-from-file startup-script=startup.sh
#gcloud compute target-pools create $TEAM-pool --region $REGION

#Create a managed instance group based on the template.
gcloud compute instance-groups managed create $TEAM-group --template $TEAM-template --size 2  --region $REGION

#Create a firewall rule named as Firewall rule to allow traffic (80/tcp)
gcloud compute firewall-rules create $FIRENAME --allow tcp:80 --network $VPC

#Create a health check
gcloud compute http-health-checks create http $TEAM-hc

#Create a backend service and add your instance group as the backend to the backend service group with named port (http:80)
gcloud compute instance-groups managed set-named-ports $TEAM-group --named-ports $PORT_NAME --region $REGION
gcloud compute backend-services create $TEAM-service --protocol HTTP   --health-checks $TEAM-hc --global
gcloud compute backend-services add-backend $TEAM-service --instance-group $TEAM-group --instance-group-zone $ZONE --global

#Create a URL map, and target the HTTP proxy to route the incoming requests to the default backend service.
gcloud compute url-maps create $TEAM-map --default-service $TEAM-service

#Create a target HTTP proxy to route requests to your URL map
gcloud compute target-http-proxies create $TEAM-proxy   --url-map $TEAM-map

#Create address and forwarding rule
gcloud compute forwarding-rules create $TEAM-fw  --global  --target-http-proxy $TEAM-proxy  --ports $PORT_NO

echo "Successfull end of resources creation and setup. Lab concluded."

# export INSTANCE=
# export PORT_NO=
# export FIREWALL=
# export ZONE=

# curl -LO raw.githubusercontent.com/QUICK-GCP-LAB/2-Minutes-Labs-Solutions/main/Implement%20Load%20Balancing%20on%20Compute%20Engine%20Challenge%20Lab/gsp313.sh
# sudo chmod +x gsp313.sh
# ./gsp313.sh