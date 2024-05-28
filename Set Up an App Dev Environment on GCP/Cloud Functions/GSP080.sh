GREEN=`tput setaf 2`
BLUE=`tput setaf 4`
REGION=us-east1
BUCKET_NAME=$DEVSHELL_PROJECT_ID

echo "${BLUE}1. Create a function triggered via pub/sub topic events"

gcloud config set compute/region REGION

mkdir gcf_hello_world && cd gcf_hello_world

cat << EOF > index.js
/**
* Background Cloud Function to be triggered by Pub/Sub.
* This function is exported by index.js, and executed when
* the trigger topic receives a message.
*
* @param {object} data The event payload.
* @param {object} context The event metadata.
*/
exports.helloWorld = (data, context) => {
const pubSubMessage = data;
const name = pubSubMessage.data
    ? Buffer.from(pubSubMessage.data, 'base64').toString() : "Hello World";

console.log(`My Cloud Function: ${name}`);
};
EOF

echo "${BLUE}2. Create a Cloud Storage bucket"
gsutil mb -p $BUCKET_NAME gs://$DEVSHELL_PROJECT_ID

echo "${BLUE}3. Deploy the function"
#When deploying a new function, you must specify --trigger-topic, --trigger-bucket, or --trigger-http. When deploying an update to an existing function, the function keeps the existing trigger unless otherwise specified.

#Disable and Re-enable the Cloud Functions API:
gcloud services disable cloudfunctions.googleapis.com && gcloud services enable cloudfunctions.googleapis.com

#Add the artifactregistry.reader permission for your appspot service account
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
--member="serviceAccount:$DEVSHELL_PROJECT_ID@appspot.gserviceaccount.com" \
--role="roles/artifactregistry.reader"

gcloud functions deploy helloWorld \
  --stage-bucket $BUCKET_NAME \
  --trigger-topic hello_world \
  --runtime nodejs20

#Verify status
gcloud functions describe helloWorld

echo "${BLUE}4. Testing the function"
DATA=$(printf 'Hello World!'|base64) && gcloud functions call helloWorld --data '{"data":"'$DATA'"}'

echo "${BLUE}5. View logs"
gcloud functions logs read helloWorld

echo "${GREEN}Successfull end of resources creation and setup. Lab concluded."