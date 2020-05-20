Déploiement de l’architecture : 

Ce projet contient des sous répertoires qui permettent de générer un workflow : 
-	Analyse des documents téléchargés sur GCS à la recherche de logiciels malveillants.
-	Envoie automatique des fichiers dans le stockage correspondant 
-	Suppression des fichiers corrompus 1 jour plus tard
-	Envoie automatique des fichiers CSV non corrompus dans la base de données Bigquery
-	Mise à disposition d’une base de données évolutive et automatiquement mis à jour 
-	Enregistrement des logs d’accès aux données dans un compartiment GCS
Durant le déploiement de cette solution, nous utiliserons les services google suivant : 
-	AppEngine pour le déploiement de notre antivirus scanneur 
-	Compute Engine pour exécuter le job cron qui est un script bash permettant de supprimer les fichiers malveillants
-	Google Cloud Storage pour le stockage de nos fichiers et nos artifact contenant l’environnement complet y compris tous les outils et dépendances nécessaires. 
-	Cloud Functions qui une plate-forme de calcul Google Cloud sans serveur basée sur des événements, qui assure un scaling automatique, une haute disponibilité et une tolérance aux pannes sans serveur à provisionner, gérer, mettre à jour ou corriger
-	Bigquery sera mis à disposition des utilisateurs finaux avec des données mis à jour en continue. 
Le déploiement de cette architecture est automatique et se fait comme suit : 
-	Créer un projet GCP
-	Cloner le répertoire du projet depuis git situer à l’url suivant ‘https://github.com/zeidane97/architecture_serverless.git’
-	Se positionner dans le répertoire 
Le script zeidane_architecture_serverless_deployment.sh contient les étapes de déploiement de notre environnement gcp .
Avant son exécution si c’est la première fois vous déployer une application app Engine, modifié l’entrée dans le script : 
sed -i -e "s/malware-scanner/default/g" \ 
appengine-malwarescanningservice-node/app.yaml

 


-	Donner les droits d’exécution au script et exécuter 
chmod + zeidane_architecture_serverless_deployment.sh && \
 bash zeidane_architecture_serverless_deployment.sh

-	Ajouter des règles IAM aux utilisateurs en écriture uniquement, sans être en mesure de supprimer des fichiers ni accéder aux autorisations :
gsutil iam ch user:’your user mail’:roles/\
storage.objectCreator gs://staging-area-$DEVSHELL_PROJECT_ID 

Remplacer ‘your user mail’ par l’adresse de votre utilisateur


