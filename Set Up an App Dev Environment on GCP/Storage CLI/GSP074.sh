echo "1. Create a bucket"
export BUCKET_NAME=$DEVSHELL_PROJECT_ID

#follow the universal bucket naming rules:
#Do not include sensitive information in the bucket name, because the bucket namespace is global and publicly visible.
#Bucket names must contain only lowercase letters, numbers, dashes (-), underscores (_), and dots (.).
#   Names containing dots are recognized as domain names and therefore require verification.
#Bucket names must start and end with a number or letter.
#Bucket names must be between 3 and 63 characters long.
#Bucket names must not be formatted as an IP address dotted-decimal notation (for example, 192.168.5.4)
#Bucket names cannot resemble goog(-le)
#Also, for DNS compliance and future compatibility, you should not use underscores (_) or have a period adjacent to another period or dash. For example, ".." or "-." or ".-" are not valid in DNS names.

gsutil mb gs://$BUCKET_NAME
echo "Sucessfully created $BUCKET_NAME"

echo "2. Upload an object into your bucket"
export EXTERNAL_ASSET=https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg

export FILE=ada.jpg
curl $EXTERNAL_ASSET --output $FILE

gsutil cp $FILE gs://$BUCKET_NAME
rm $FILE && echo "Sucessfully uploaded an object into $BUCKET_NAME"

echo "3. Download an object from your bucket"
gsutil cp -r gs://$BUCKET_NAME/$FILE . && echo "Sucessfully downloaded an object from $BUCKET_NAME"

echo "4. Copy an object to a folder in the bucket"
export FOLDER=image-folder #$FILE-dir
gsutil cp gs://$BUCKET_NAME/$FILE gs://$BUCKET_NAME/$FOLDER/

echo "5. List contents of a bucket or folder"
gsutil ls gs://$BUCKET_NAME

echo "6. List details for an object"
gsutil ls -l gs://$BUCKET_NAME/$FILE

echo "7. Make your object publicly accessible"
gsutil acl ch -u AllUsers:R gs://$BUCKET_NAME/$FILE