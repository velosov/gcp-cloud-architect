region=us-central1
zone=us-central1-c

echo "1. Configure the gcloud environment"

gcloud --version
gcloud compute ssh centos-clean --zone $zone
gcloud --version
gcloud auth login

gcloud config set compute/region $region
gcloud config set compute/zone $zone

#Create an instance with name as lab-1 in Project 1
gcloud compute instances create lab-1 --zone $zone --machine-type=e2-standard-2
gcloud config list

#Change curent zone to another in the same region
zone2=$(gcloud compute zones list | grep -i $region | grep -v $zone | head -n 1)
gcloud config set compute/zone $zone2
gcloud config list
#Default configuration is stored in ~/.config/gcloud/configurations/config_default
cat ~/.config/gcloud/configurations/config_default

echo "2. Create and switch between multiple IAM configurations"
#Start a new gcloud configuration for the second user account
echo "Select option 2, Create a new configuration"
user2=$(read -p "Enter second account email (like student-03-787155517e88@qwiklabs.net): ")

echo "Configuration name: Type user2 and login with 2nd account"
echo "Log in with a new account: select option 3 - you're logging in with the other provided user name"
gcloud init --no-launch-browser

gcloud config configurations activate default

echo "3. Identify and assign correct IAM permissions"
#View all roles
gcloud iam roles list | grep "name:"
#View role permissions: gcloud iam roles describe roles/service.role

sudo yum -y install epel-release
sudo yum -y install jq

echo "Granting new user access to 2nd project"
echo "export USERID2="$user2"" >> ~/.bashrc

. ~/.bashrc
PROJECTID2=$(read -p "Enter the project ID for the second project: ")
gcloud projects add-iam-policy-binding $PROJECTID2 --member user:$user2 --role=roles/viewer

gcloud config configurations activate $user2
echo "export PROJECTID2="$PROJECTID2"" >> ~/.bashrc

. ~/.bashrc
gcloud config set project $PROJECTID2
#Verify
gcloud compute instances list

gcloud config configurations activate default
gcloud iam roles create devops --project $PROJECTID2 --permissions "compute.instances.create,compute.instances.delete,compute.instances.start,compute.instances.stop,compute.instances.update,compute.disks.create,compute.subnetworks.use,compute.subnetworks.useExternalIp,compute.instances.setMetadata,compute.instances.setServiceAccount"

gcloud projects add-iam-policy-binding $PROJECTID2 --member user:$user2 --role=roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $PROJECTID2 --member user:$user2 --role=projects/$PROJECTID2/roles/devops

#Test
zone2=$(read -p "Enter chosen test zone (e.g. us-east4-b)")

gcloud config configurations activate $user2
gcloud compute instances create lab-2 --zone $zone2 --machine-type=e2-standard-2
gcloud compute instances list
gcloud config configurations activate default

#Service Accounts
gcloud config set project $PROJECTID2

#Create
gcloud iam service-accounts create devops --display-name devops

#Get the service account email address. 
SA=$(gcloud iam service-accounts list --format="value(email)" --filter "displayName=devops")

gcloud projects add-iam-policy-binding $PROJECTID2 --member serviceAccount:$SA --role=roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $PROJECTID2 --member serviceAccount:$SA --role=roles/compute.instanceAdmin

gcloud compute instances create lab-3 --zone us-east4-b --machine-type=e2-standard-2 --service-account $SA --scopes "https://www.googleapis.com/auth/compute"