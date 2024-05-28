#1. Enable Compute Engine API
gcloud services enable compute.googleapis.com

#2. Create Cloud Storage bucket
gsutil mb gs://fancy-store-$DEVSHELL_PROJECT_ID

#3. Clone source repository
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices && ./setup.sh

# nvm install --lts
# cd ~/microservices && npm start

#4. Create Compute Engine instances
#startup script
cat > startup-script.sh <<EOF_START
#!/bin/bash

# Install logging monitor. The monitor will automatically pick up logs sent to
# syslog.
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &

# Install dependencies from apt
apt-get update
apt-get install -yq ca-certificates git build-essential supervisor psmisc

# Install nodejs
mkdir /opt/nodejs
curl https://nodejs.org/dist/v16.14.0/node-v16.14.0-linux-x64.tar.gz | tar xvzf - -C /opt/nodejs --strip-components=1
ln -s /opt/nodejs/bin/node /usr/bin/node
ln -s /opt/nodejs/bin/npm /usr/bin/npm

# Get the application source code from the Google Cloud Storage bucket.
mkdir /fancy-store
gsutil -m cp -r gs://fancy-store-[DEVSHELL_PROJECT_ID]/monolith-to-microservices/microservices/* /fancy-store/

# Install app dependencies.
cd /fancy-store/
npm install

# Create a nodeapp user. The application will run as this user.
useradd -m -d /home/nodeapp nodeapp
chown -R nodeapp:nodeapp /opt/app

# Configure supervisor to run the node app.
cat >/etc/supervisor/conf.d/node-app.conf << EOF
[program:nodeapp]
directory=/fancy-store
command=npm start
autostart=true
autorestart=true
user=nodeapp
environment=HOME="/home/nodeapp",USER="nodeapp",NODE_ENV="production"
stdout_logfile=syslog
stderr_logfile=syslog
EOF

supervisorctl reread
supervisorctl update
EOF_START

#https://storage.googleapis.com/[BUCKET_NAME]/startup-script.sh :
gsutil cp ~/monolith-to-microservices/startup-script.sh gs://fancy-store-$DEVSHELL_PROJECT_ID

#1.Copy the cloned code into your bucket:
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

#Deploy the backend instance
ZONE=us-east4-b

gcloud compute instances create backend \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --tags=backend \
   --metadata=startup-script-url=https://storage.googleapis.com/fancy-store-$DEVSHELL_PROJECT_ID/startup-script.sh
#create an e2-standard-2 instance that is configured to use the startup script (notice tags for further fw rules)

#Configure a connection to the backend
#Retrieve backend's external IP address
gcloud compute instances list
EXTERNAL_IP=$(read -p "Enter the external IP address of the backend instance: ")

cd ~/monolith-to-microservices/react-app
sed -i "s/localhost/$EXTERNAL_IP/g" .env

npm install && npm run-script build
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

#Deploy the frontend instance
gcloud compute instances create frontend \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --tags=frontend \
    --metadata=startup-script-url=https://storage.googleapis.com/fancy-store-$DEVSHELL_PROJECT_ID/startup-script.sh

#Create a firewall rule to allow traffic on port 8080
gcloud compute firewall-rules create fw-fe \
    --allow tcp:8080 \
    --target-tags=frontend
gcloud compute firewall-rules create fw-be \
    --allow tcp:8081-8082 \
    --target-tags=backend

gcloud compute instances list

#Create instance template from source instance
gcloud compute instances stop frontend --zone=$ZONE && gcloud compute instances stop backend --zone=$ZONE
gcloud compute instance-templates create fancy-fe \
    --source-instance-zone=$ZONE \
    --source-instance=frontend
gcloud compute instance-templates create fancy-be \
    --source-instance-zone=$ZONE \
    --source-instance=backend
gcloud compute instance-templates list
gcloud compute instances delete backend --zone=$ZONE

#Create managed instance group
gcloud compute instance-groups managed create fancy-fe-mig \
    --base-instance-name=fancy-fe \
    --template=fancy-fe \
    --size=2 \
    --zone=$ZONE
gcloud compute instance-groups managed create fancy-be-mig \
    --zone=$ZONE \
    --base-instance-name fancy-be \
    --size 2 \
    --template fancy-be

#frontend microservice runs on port 8080, and the backend microservice runs on non-standard ports 8081 for orders and port 8082 for products
gcloud compute instance-groups set-named-ports fancy-fe-mig \
    --zone=$ZONE \
    --named-ports frontend:8080
gcloud compute instance-groups set-named-ports fancy-be-mig \
    --zone=$ZONE \
    --named-ports orders:8081,products:8082
#Named ports are key:value pair metadata representing the service name and the port that it's running on. Named ports can be assigned to an instance group, and is used by LB

#Configure autohealing
#Note: Separate health checks for load balancing and for autohealing will be used. Health checks for load balancing can and should be more aggressive because these health checks determine whether an instance receives user traffic. You want to catch non-responsive instances quickly so you can redirect traffic if necessary. In contrast, health checking for autohealing causes Compute Engine to proactively replace failing instances, so this health check should be more conservative than a load balancing health check.
#health check that repairs the instance if it returns "unhealthy" 3 consecutive times for the frontend and backend
gcloud compute health-checks create http fancy-fe-hc \
    --port 8080 \
    --check-interval 30s \
    --healthy-threshold 1 \
    --timeout 10s \
    --unhealthy-threshold 3
gcloud compute health-checks create http fancy-be-hc \
    --port 8081 \
    --request-path=/api/orders \
    --check-interval 30s \
    --healthy-threshold 1 \
    --timeout 10s \
    --unhealthy-threshold 3

#firewall rule to allow the health check probes to connect to the microservices on ports 8080-8081
gcloud compute firewall-rules create allow-health-check \
    --allow tcp:8080-8081 \
    --source-ranges 130.211.0.0/22,35.191.0.0/16 \
    --network default

#apply hc
gcloud compute instance-groups managed update fancy-fe-mig \
    --zone=$ZONE \
    --health-check fancy-fe-hc \
    --initial-delay 300
gcloud compute instance-groups managed update fancy-be-mig \
    --zone=$ZONE \
    --health-check fancy-be-hc \
    --initial-delay 300

#Create HTTP(S) load balancer
#A forwarding rule directs incoming requests to a target HTTP proxy.
#The target HTTP proxy checks each request against a URL map to determine the appropriate backend service for the request.
#The backend service directs each request to an appropriate backend based on serving capacity, zone, and instance health of its attached backends. The health of each backend instance is verified using an HTTP health check. If the backend service is configured to use an HTTPS or HTTP/2 health check, the request will be encrypted on its way to the backend instance.
#Sessions between the load balancer and the instance can use the HTTP, HTTPS, or HTTP/2 protocol. If you use HTTPS or HTTP/2, each instance in the backend services must have an SSL certificate.
gcloud compute http-health-checks create fancy-fe-frontend-hc \
  --request-path / \
  --port 8080
gcloud compute http-health-checks create fancy-be-orders-hc \
  --request-path /api/orders \
  --port 8081
gcloud compute http-health-checks create fancy-be-products-hc \
  --request-path /api/products \
  --port 8082
#Note: These health checks are for the load balancer, and only handle directing traffic from the load balancer; they do not cause the managed instance groups to recreate instances.

#backend services that are the target for load-balanced traffic
gcloud compute backend-services create fancy-fe-frontend \
  --http-health-checks fancy-fe-frontend-hc \
  --port-name frontend \
  --global
gcloud compute backend-services create fancy-be-orders \
  --http-health-checks fancy-be-orders-hc \
  --port-name orders \
  --global
gcloud compute backend-services create fancy-be-products \
  --http-health-checks fancy-be-products-hc \
  --port-name products \
  --global

#Add the Load Balancer's backend services:
gcloud compute backend-services add-backend fancy-fe-frontend \
  --instance-group-zone=$ZONE \
  --instance-group fancy-fe-mig \
  --global
gcloud compute backend-services add-backend fancy-be-orders \
  --instance-group-zone=$ZONE \
  --instance-group fancy-be-mig \
  --global
gcloud compute backend-services add-backend fancy-be-products \
  --instance-group-zone=$ZONE \
  --instance-group fancy-be-mig \
  --global

#Create a URL map defining which URLs are directed to which backend services
gcloud compute url-maps create fancy-map \
  --default-service fancy-fe-frontend

#Create a path matcher to allow the /api/orders and /api/products paths to route to their respective services
gcloud compute url-maps add-path-matcher fancy-map \
   --default-service fancy-fe-frontend \
   --path-matcher-name orders \
   --path-rules "/api/orders=fancy-be-orders,/api/products=fancy-be-products"

#Create the proxy which ties to the URL map:
gcloud compute target-http-proxies create fancy-proxy \
  --url-map fancy-map

#Create a global forwarding rule that ties a public IP address and port to the proxy
gcloud compute forwarding-rules create fancy-http-rule \
  --global \
  --target-http-proxy fancy-proxy \
  --ports 80

#Update the configuration w/ new static IP address
cd ~/monolith-to-microservices/react-app/

gcloud compute forwarding-rules list --global
LB_IP=$(read -p "Enter the LB's external IP address: ")
sed -i "s/localhost/$LB_IP/g" .env

cd ~/monolith-to-microservices/react-app
npm install && npm run-script build

cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

#Pull updated code from bucket to instances
gcloud compute instance-groups managed rolling-action replace fancy-fe-mig \
    --zone=$ZONE \
    --max-unavailable 100%


#7. Scaling Compute Engine
#create an autoscaler on the managed instance groups that automatically adds instances when utilization is above 60% utilization, and removes instances when the load balancer is below 60% utilization
gcloud compute instance-groups managed set-autoscaling \
  fancy-fe-mig \
  --zone=$ZONE \
  --max-num-replicas 2 \
  --target-load-balancing-utilization 0.60

gcloud compute instance-groups managed set-autoscaling \
  fancy-be-mig \
  --zone=$ZONE \
  --max-num-replicas 2 \
  --target-load-balancing-utilization 0.60

#Enable content delivery network - When a user requests content from the HTTP(S) load balancer, the request arrives at a Google Front End (GFE) which first looks in the Cloud CDN cache for a response to the user's request.
gcloud compute backend-services update fancy-fe-frontend \
    --enable-cdn --global


#8. Updating instance template - templates are not editable; however, since your instances are stateless and all configuration is done through the startup script, you only need to change the instance template if you want to change the template settings
#simple change to use a larger machine type, then push
gcloud compute instances set-machine-type frontend \
  --zone=$ZONE \
  --machine-type e2-small

#Create the new Instance Template:
gcloud compute instance-templates create fancy-fe-new \
    --region=$REGION \
    --source-instance=frontend \
    --source-instance-zone=$ZONE

#Roll out the updated instance template to the Managed Instance Group:
gcloud compute instance-groups managed rolling-action start-update fancy-fe-mig \
  --zone=$ZONE \
  --version template=fancy-fe-new

#Wait 3 minutes, and then run the following to monitor the status of the update:
#watch -n 2 gcloud compute instance-groups managed list-instances fancy-fe-mig --zone=$ZONE

#Run the following to see if the virtual machine is using the new machine type (e2-small), where [VM_NAME] is the newly created instance:
# gcloud compute instances describe [VM_NAME] --zone=$ZONE | grep machineType

#Making changes - Scenario: update index.js with index.js.new's file content
#copy the updated file to the correct file name:
cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js

cat ~/monolith-to-microservices/react-app/src/pages/Home/index.js

#build + push
cd ~/monolith-to-microservices/react-app
npm install && npm run-script build

cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

#Force all instances to be replaced to pull the update:
gcloud compute instance-groups managed rolling-action replace fancy-fe-mig \
  --zone=$ZONE \
  --max-unavailable=100%
#immediately through the --max-unavailable parameter. Without this parameter, the command would keep an instance alive while replacing others

# watch -n 2 gcloud compute backend-services get-health fancy-fe-frontend --global
# gcloud compute forwarding-rules list --global

#Simulate failure
#find an instance name ad ssh into it
INSTANCE=$(gcloud compute instance-groups list-instances fancy-fe-mig --zone=$ZONE | head -n 1)
gcloud compute ssh $INSTANCE --zone=$ZONE

#Within the instance, use supervisorctl to stop the application
sudo supervisorctl stop nodeapp; sudo killall node; exit

#Monitor the repair operations:
watch -n 2 gcloud compute operations list \
--filter='operationType~compute.instances.repair.*'