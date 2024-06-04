#Heterogeneous deployments typically involve connecting two or more distinct infrastructure environments or regions to address a specific technical or operational need.
#Heterogeneous deployments are called "hybrid", "multi-cloud", or "public-private", depending upon the specifics of the deployment.

#1. Setup
ZONE=$(read -p "Enter the zone for the cluster: ")
gcloud config set compute/zone $ZONE
gsutil -m cp -r gs://spls/gsp053/orchestrate-with-kubernetes .
#git clone https://github.com/googlecodelabs/orchestrate-with-kubernetes.git
cd orchestrate-with-kubernetes/kubernetes

#Create a GKE cluster with 3 nodes
gcloud container clusters create bootcamp \
  --machine-type e2-small \
  --num-nodes 3 \
  --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"

#explain command in kubectl can tell us about the deployment object
kubectl explain deployment
#--recursive for all of the fields; dotting for specific ones (like kubectl explain deployment.metadata.name)

#2. Create deployments
echo "This script supposes you updated the deployment's image and version to 1.0.0 according to lab instructions" && read -p "Press any key to continue"

kubectl create -f deployments/auth.yaml
#Once the deployment is created, Kubernetes will create a ReplicaSet (with a name like auth-xxxxxxx) for the deployment
kubectl get replicasets
#notice pod is created by together with ReplicaSet during deployment, according to specified in Deployment manifest
kubectl create -f services/auth.yaml

kubectl create -f deployments/hello.yaml
kubectl create -f services/hello.yaml

kubectl create secret generic tls-certs --from-file tls/
kubectl create configmap nginx-frontend-conf --from-file=nginx/frontend.conf
kubectl create -f deployments/frontend.yaml
kubectl create -f services/frontend.yaml

#output templating feature of kubectl:
curl -ks https://`kubectl get svc frontend -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`

#Scale a deployment
kubectl explain deployment.spec.replicas
#field above determines the number of replicas

kubectl scale deployment hello --replicas=5
echo "Note: It may take a minute or so for all the new pods to start up."

kubectl get pods | grep hello- | wc -l
kubectl scale deployment hello --replicas=3 && !!

#3. Rolling update
#Deployments support updating images to a new version through a rolling update mechanism.
#When a deployment is updated with a new version, it creates a new ReplicaSet and slowly increases the number of replicas in the new ReplicaSet as it decreases the replicas in the old ReplicaSet.
kubectl edit deployment hello
kubectl rollout history deployment/hello

# If you detect problems with a running rollout, pause it to stop the update.
kubectl rollout pause deployment/hello && kubectl rollout status deployment/hello
# kubectl get pods -o jsonpath --template='{range .items[*]}{.metadata.name}{"\t"}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
kubectl rollout resume deployment/hello

# Rolling an update back
kubectl rollout undo deployment/hello && kubectl rollout history deployment/hello
kubectl get pods -o jsonpath --template='{range .items[*]}{.metadata.name}{"\t"}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

#4. Canary deployments
#Use a canary deployment to test a new one in production with a subset of users.
#Canary deployments allows releasing a change to a small subset of users to mitigate risk associated with new releases.
#signaled at deployment.spec.template.metadata.labels.track
kubectl create -f deployments/hello-canary.yaml

#In this lab, each request sent to the Nginx service had a chance to be served by the canary deployment.
#But what if we wanted to ensure that a user didn't get served by the canary deployment?
#A use case could be that the UI for an application changed, and we don't want to confuse the user.
#In a case like this, we want the user to "stick" to one deployment or the other.

#One can do this by creating a service with session affinity. This way the same user will always be served from the same version. Field sessionAffinity when set to ClientIP routes all clients with the same IP address always to the same version of the application.

#5. Blue-green deployments
# Rolling updates are ideal because they allow you to deploy an application slowly with minimal overhead, minimal performance impact, and minimal downtime.
# There are instances where it is beneficial to modify the load balancers to point to that new version only after it has been fully deployed.
# In this case, blue-green deployments are the way to go.

# Kubernetes achieves this by creating two separate deployments; one for the old "blue" version and one for the new "green" version.
# Use your existing hello deployment for the "blue" version. The deployments will be accessed via a service which will act as the router.
# Once the new "green" version is up and running, you'll switch over to using that version by updating the service.

# Note: A major downside of blue-green deployments is that you will need to have at least 2x the resources in your cluster necessary to host your application. Make sure you have enough resources in your cluster before deploying both versions of the application at once.

#Update existing service so that it has a selector app:hello, version: 1.0.0
#The selector will match the existing "blue" deployment, but won't match the "green" one because it will use a different version
kubectl apply -f services/hello-blue.yaml
#Note: Ignore the warning that says resource service/hello is missing as this is patched automatically.

#In order to support a blue-green deployment style, create a new "green" deployment for the new version. 
kubectl create -f deployments/hello-green.yaml
#The green deployment points to updated version label and image path.

#verify 1 is still in use:
curl -ks https://`kubectl get svc frontend -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version
kubectl apply -f services/hello-green.yaml && !!
#after service is updated, green deployment immediately starts to be used

#rollback is simple as well, keep blue service running and:
kubectl apply -f services/hello-blue.yaml