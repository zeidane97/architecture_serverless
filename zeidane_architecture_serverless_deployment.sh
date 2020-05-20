#!/bin/bash
#****************************************************************************
#ce script permet déployer sur GCP 
#un serveur de transfert de fichier en architecture serverless 

# Author...... : zeidane AGBANRIN 
# Created..... : 15/05/2020
# Modified.... : /15/05/2020
# Notes....... :
#**************************************************************************
VERSION=1.0.0

#Se positionner dans le repertoire HiringChallenge sur GCP à l'aide de cloud shell ou Google SDk en local
#Execution du script sans interacion 
gcloud config set disable_prompts true

#Dans ce projet nous allons travailler dans la région europe et comme zone de disponibilité Londres
#Définissez la région et la zone
gcloud config set compute/zone europe-west2-a

#Crez une  variable d'environnement pour l'ID de votre projet Google Cloud, on s'en servira pour la création de nos compartiments
export PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID --format='value(projectNumber)')

#Suivant notre architecture, nous aurons besoins de quatres compartiments :
#Création des compartiments :

gsutil mb gs://staging-area-$DEVSHELL_PROJECT_ID
gsutil mb gs://suspect-files-$DEVSHELL_PROJECT_ID
gsutil mb gs://sain-files-$DEVSHELL_PROJECT_ID
gsutil mb gs://logs-bucket-$DEVSHELL_PROJECT_ID

#Partie 1 : deployer la supervion sur le bucket staging-area
#Définissez les autorisations de manière à accorder à Cloud Storage l'autorisation WRITE
gsutil acl ch -g cloud-storage-analytics@google.com:W gs://logs-bucket-$DEVSHELL_PROJECT_ID
#Activez la journalisation du bucket.
gsutil logging set on -b gs://logs-bucket-$DEVSHELL_PROJECT_ID -o AccessLog gs://staging-area-$DEVSHELL_PROJECT_ID

#Partie 2 :création du service de déploiement de logiciels malveillants 
cd appengine-malwarescanningservice-node

#Remplacer dans le fichier app.yaml PROJECT_ID par le nom de notre projet 
sed -i -e "s/PROJECT_ID/$DEVSHELL_PROJECT_ID/g" app.yaml

#S'il s'agit du premier service que vous déployez sur App Engine, définissez le nom du service dans
#le fichier app.yaml actuel de ce répertoire sur default :
#Création du service et déploiement sur AppEngine
gcloud app create --project=$DEVSHELL_PROJECT_ID --region=europe-west2
gcloud app deploy 

#Notez l'url du service qui s'affiche
echo "Notez l'url du service qui s'affiche"

#se poistionner dans le repos
cd ../function-scantrigger-node/

#Remplaçant https://malware-scanner-dot-PROJECT_ID.appspot.com par l'URL de service
#que vous avez copiée précédemment. Voici l'exemple dans notrre cas 
service_url="https://malware-scanner-dot-$DEVSHELL_PROJECT_ID.nw.r.appspot.com"

#Recherchez le nom du compte de service de l'environnement flexible App Engine, car vous en aurez besoin
#lors de la prochaine étape permettant d'attribuer des autorisations d'accès aux buckets créés. Le compte
#de service est au format suivant :
service_account="service-${PROJECT_NUMBER}@gae-api-prod.google.com.iam.gserviceaccount.com"

#Ajoutez le compte de service App Engine en tant que membre avec le rôle roles/storage.legacyBucketWriter au bucket staging-area-PROJECT_ID :
gsutil iam ch serviceAccount:$service_account:roles/storage.legacyBucketWriter gs://staging-area-$DEVSHELL_PROJECT_ID

#Ajoutez le compte de service App Engine en tant que membre avec le rôle roles/storage.objectCreator au bucket suspect_files-PROJECT_ID :
gsutil iam ch serviceAccount:$service_account:roles/storage.objectCreator gs://suspect-files-$DEVSHELL_PROJECT_ID

#Ajoutez le compte de service App Engine en tant que membre avec le rôle roles/storage.objectCreator au bucket sain-files-PROJECT_ID/var> :
gsutil iam ch serviceAccount:$service_account:roles/storage.objectCreator gs://sain-files-$DEVSHELL_PROJECT_ID

#Créer une fonction Cloud pour déclencher le service de détection de logiciels malveillants
#Déployez la fonction en remplaçant https://malware-scanner-dot-PROJECT_ID.appspot.com par l'URL de service que vous avez copiée précédemment.
gcloud functions deploy requestMalwareScan \
    --runtime nodejs8 \
    --set-env-vars SCAN_SERVICE_URL=$service_url/scan \
    --trigger-resource gs://staging-area-$DEVSHELL_PROJECT_ID \
    --trigger-event google.storage.object.finalize

#Revenir dans le repertoir racine
cd ..

#Créeons un fichier  normal qui sera uploader dans le compartiment sain-files pour tester la fonction

echo "am not a corrupt file and you???" > RightFile.txt
gsutil cp RightFile.txt gs://staging-area-$DEVSHELL_PROJECT_ID/

#Créons cette fois si un fichier corrompu :
#L’Institut européen pour EICAR a développé le fichier de test anti-malware EICAR. Le fichier de test EICAR est un 
#programme DOS légitime qui est détecté comme logiciel malveillant par un logiciel antivirus.

echo -e 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar-infected.txt
gsutil cp eicar-infected.txt gs://staging-area-$DEVSHELL_PROJECT_ID/
#Delete les 2 fichiers du repos
rm RightFile.txt
rm eicar-infected.txt
#Vérifions le bon fonctionnement de notre  antivirus
gsutil ls -r  gs://sain-files-$DEVSHELL_PROJECT_ID/
gsutil ls -r gs://suspect-files-$DEVSHELL_PROJECT_ID/


#Partie 3 : Pousser les fichiers csv dans Bigquery en utilisant cloud fucntion
cd function-insert-intoBigQuery/

#Deployer la fonction loadFile
gcloud functions deploy loadFile --runtime nodejs8 --trigger-resource \
        gs://sain-files-$DEVSHELL_PROJECT_ID --trigger-event google.storage.object.finalize


#Creer un dataset 'worldcountry' dans Bigquery et une table 'country' 
bq mk worldcountry
bq mk worldcountry.country schema.json 
#Ajoutons le fichier sample.csv pour tester le fonctionnement : 
gsutil cp sql-pays.csv gs://staging-area-$DEVSHELL_PROJECT_ID

#Les données doivent être disponible dans BigQuery
#Partie 4 : Deploiement de la fonction delete qui permet de supprimer les fichiers 
cd ../..
mkdir cronjob
cp delete_old_file.sh cronjob/
chmod +x cronjob/delete_old_file.sh
crontab -l > mycron
echo "00 03 * * *  bash cronjob/delete_old_file.sh" >> mycron
crontab mycron
rm mycron
echo 'Les données doivent être disponible dans BigQuery.'
