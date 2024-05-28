#1. Topics
Topic=myTopic
gcloud pubsub topics create $Topic
gcloud pubsub topics create Test1
gcloud pubsub topics create Test2

gcloud pubsub topics list
gcloud pubsub topics delete Test1 && gcloud pubsub topics delete Test2
gcloud pubsub topics list

#2. Subscriptions
SUB=mySubscription

gcloud  pubsub subscriptions create --topic $Topic $SUB

gcloud  pubsub subscriptions create --topic $Topic Test1
gcloud  pubsub subscriptions create --topic $Topic Test2
gcloud pubsub topics list-subscriptions $Topic

gcloud pubsub subscriptions delete Test1 && gcloud pubsub subscriptions delete Test2
gcloud pubsub topics list-subscriptions $Topic

#3. Publishing and pulling messages

gcloud pubsub topics publish $Topic --message "Hello"
gcloud pubsub topics publish $Topic --message "Publisher's name is Vini"
gcloud pubsub topics publish $Topic --message "Publisher roots for Vasco and Eagles"

#single-message command
gcloud pubsub subscriptions pull $SUB --auto-ack

#multiple-message flag
gcloud pubsub topics publish $Topic --message "Publisher is starting to get the hang of Pub/Sub"
gcloud pubsub topics publish $Topic --message "Publisher wonders if all messages will be pulled"
gcloud pubsub topics publish $Topic --message "Publisher will have to test to find out"

gcloud pubsub subscriptions pull $SUB --auto-ack --limit=3