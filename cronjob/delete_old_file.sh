#!/bin/bash

#today date
BUCKET_NAME="suspect-files-$DEVSHELL_PROJECT_ID "
zeidane=$(date +"%Y-%m-%d")
#yesterday date
#date -d "$zeidane -1 days" +%Y-%m-%d
gsutil rm -r $(gsutil ls -l gs://$BUCKET_NAME  | grep $(date -d "$zeidane -1 days" +%Y-%m-%d) | awk '{print $3}')
