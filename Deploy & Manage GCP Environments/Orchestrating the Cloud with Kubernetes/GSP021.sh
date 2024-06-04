# 1. Setup
gcloud config set compute/zone us-east4-b
gcloud container clusters create io --zone us-east4-b
#You are automatically authenticated to your cluster upon creation. If you lose connection to your Cloud Shell for any reason, run the gcloud container clusters get-credentials io command to re-authenticate.
gsutil cp -r gs://spls/gsp021/* . && cd orchestrate-with-kubernetes/kubernetes
#git clone https://github.com/googlecodelabs/orchestrate-with-kubernetes.git

#2. Create a Kubernetes cluster and launch Nginx container

#The easiest way to get started with Kubernetes is to use the kubectl create
#launch a single instance of the nginx container

kubectl create deployment nginx --image=nginx:1.10.0
#deployments keep the pods up and running even when the nodes they run on fail

#all containers run in a pod
kubectl get pods
kubectl describe pods monolith
#information about the monolith pod including the Pod IP address and the event log

#Once the container has a Running status you can expose it outside of Kubernetes using kubectl expose
kubectl expose deployment nginx --port 80 --type LoadBalancer
#Behind the scenes Kubernetes creates an external Load Balancer with a public IP address attached to it. Any client who hits that public IP address will be routed to the pods behind the service. In this case that would be the nginx pod.

#list services
kubectl get services
#Note: It may take a few seconds before the ExternalIP field is populated for your service. This is normal -- just re-run the kubectl get services command every few seconds until the field populates.


#3-5. Pods
cd ~/orchestrate-with-kubernetes/kubernetes && cat pods/monolith.yaml
# cat pods/monolith.yaml
kubectl create -f pods/monolith.yaml
#Note: It may take a few seconds before the monolith pod is up and running. The monolith container image needs to be pulled from the Docker Hub before you can run it.
kubectl get pods

#By default, pods are allocated a private IP address and cannot be reached outside of the cluster. In a new tab:
kubectl port-forward monolith 10080:80
#curl http://127.0.0.1:10080
#curl http://127.0.0.1:10080/secure

TOKEN=$(curl http://127.0.0.1:10080/login -u user|jq -r '.token')

curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:10080/secure

kubectl logs monolith
# -f to follow

#Use the kubectl exec command to run an interactive shell inside the Monolith Pod. This can come in handy when you want to troubleshoot from within a container:
kubectl exec monolith --stdin --tty -c monolith /bin/sh && ping -c 3 google.com && exit

#6. Services
#Pods aren't meant to be persistent. They can be stopped or started for many reasons - like failed liveness or readiness checks - and this leads to a problem:

#What happens if you want to communicate with a set of Pods? When they get restarted they might have a different IP address.
#That's where Services come in. Services provide stable endpoints for Pods.

#Services use labels to determine what Pods they operate on. If Pods have the correct labels, they are automatically picked up and exposed by our services.
#The level of access a service provides to a set of pods depends on the Service's type. Currently there are three types:
#   ClusterIP (internal) -- the default type means that this Service is only visible inside of the cluster,
#   NodePort gives each node in the cluster an externally accessible IP and
#   LoadBalancer adds a load balancer from the cloud provider which forwards traffic from the service to Nodes within it.

# cd ~/orchestrate-with-kubernetes/kubernetes
cat pods/secure-monolith.yaml

#Create the secure-monolith pods and their configuration data
kubectl create secret generic tls-certs --from-file tls/
kubectl create configmap nginx-proxy-conf --from-file nginx/proxy.conf
kubectl create -f pods/secure-monolith.yaml

#Expose the secure-monolith Pod

kubectl create -f services/monolith.yaml

#Kubernetes handles port assignment by default. Here we chose a port so that it's easier to configure health checks later on.

#Allow traffic to the monolith service on the exposed nodeport:
gcloud compute firewall-rules create allow-monolith-nodeport \
  --allow=tcp:31000

kubectl get services monolith
kubectl describe services monolith

kubectl get pods -l "app=monolith"
kubectl get pods -l "app=monolith,secure=enabled"

#8. Add missing label
kubectl label pods secure-monolith 'secure=enabled'
kubectl get pods secure-monolith --show-labels

kubectl describe services monolith | grep Endpoints

#9. Deploying applications with Kubernetes
#Deployments abstracts the low level details of managing Pods. They are a declarative way to ensure that the number of Pods running is equal to the desired number of Pods as specified by the user
#Behind the scenes Deployments use Replica Sets to manage (re)starting, stopping, updating and autoscaling the Pods.

#10. Break up the monolith application into 3 smaller Services using Deployments:
# auth - Generates JWT tokens for authenticated users.
# hello - Greet authenticated users.
# frontend - Routes traffic to the auth and hello services.

#create deployment objects:
kubectl create -f deployments/auth.yaml
kubectl create -f deployments/hello.yaml

#create a service for your auth deployments:
kubectl create -f services/auth.yaml
kubectl create -f services/hello.yaml

kubectl create configmap nginx-frontend-conf --from-file=nginx/frontend.conf
kubectl create -f deployments/frontend.yaml
kubectl create -f services/frontend.yaml