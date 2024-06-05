ZONE=$(read -p "Enter the zone for the cluster: ")
REGION=$(read -p "Enter the region for the cluster: ")
gcloud config set compute/zone $ZONE

#1-3. Create bastion host, dev and prod VPCs
terraform init

echo "Type yes when asked by Terraform to continue"
terraform plan && terraform apply

#4. Create and configure Cloud SQL Instance

gcloud sql instances create griffin-dev-db \
    --database-version=MYSQL_5_7 \
    --region=$REGION \
    --root-password='awesome'

gcloud sql databases create wordpress --instance=griffin-dev-db
gcloud sql users create wp_user --instance=griffin-dev-db --password=stormwind_rules --instance=griffin-dev-db
gcloud sql users set-password wp_user --instance=griffin-dev-db --password=stormwind_rules --instance=griffin-dev-db
gcloud sql users list --instance=griffin-dev-db --format="value(name)" --filter="host='%'" --instance=griffin-dev-db

#5-6. Create & Prepare Kubernetes cluster
gcloud container clusters create griffin-dev \
  --machine-type e2-standard-4 \
  --num-nodes 2 \
  --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"

#point kubectl at a specific cluster in Google Kubernetes Engine: https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials
gcloud container clusters get-credentials griffin-dev --zone $ZONE

gsutil cp -r gs://cloud-training/gsp321/wp-k8s .
cat > wp-k8s/wp-env.yaml << EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: wordpress-volumeclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: database
type: Opaque
stringData:
  username: wp_user
  password: stormwind_rules

EOF
kubectl create -f wp-env.yaml

#We also need to provide a key for a service account that was already set up. This service account provides access to the database for a sidecar container.
gcloud iam service-accounts keys create key.json \
    --iam-account=cloud-sql-proxy@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com
kubectl create secret generic cloudsql-instance-credentials \
    --from-file key.json

kubectl create -f wp-deployment.yaml
kubectl create -f wp-service.yaml

# gcloud monitoring uptime create 
gcloud projects add-iam-policy-binding qwiklabs-gcp-02-02c62c7e00dc --member user:student-02-9a5b2d5efab1@qwiklabs.net --role=roles/editor

#7. Create a WordPress deployment
#get IAM policy
IAM_POLICY_JSON=$(gcloud projects get-iam-policy $DEVSHELL_PROJECT_ID --format=json)

#filter user emails with 'roles/viewer' role
USERS=$(echo $IAM_POLICY_JSON | jq -r '.bindings[] | select(.role == "roles/viewer").members[]')

#grant editor role
for USER in $USERS; do
  if [[ $USER == *"user:"* ]]; then
    EMAIL=$(echo $USER | cut -d':' -f2)
    gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
      --member=user:$EMAIL \
      --role=roles/editor
  fi
done