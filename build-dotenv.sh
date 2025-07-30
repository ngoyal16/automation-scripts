#!/bin/bash -e
#
# Release to Bintray.
#
# Build .env file using AWS Secrets Manager
#
# Required globals:
#   AWS_SECRET_CONFIGS
#
# Optional globals:
#   DOTENV_FILE_PATH

set -e

get_secret_value() {
  secretId="$1"

  # Extract the secret string
  secret=$(aws secretsmanager get-secret-value \
    --secret-id "${secretId}" \
    --version-stage AWSCURRENT \
    --profile "${AWS_PROFILE}" \
    --output json)

  if [ $? -ne 0 ]; then
    echo "Failed while reteriving values from AWS Secret Manager, aborting."
  fi

  echo "${secret}" | jq '.SecretString' | jq fromjson | jq 'to_entries'
}

# required parameters
AWS_SECRET_CONFIGS=${AWS_SECRET_CONFIGS:?'AWS_SECRET_CONFIGS variable missing.'}

# optional parameters
DOTENV_FILE_PATH=${DOTENV_FILE_PATH:=".env"}

echo "Building .env..."


secretIds=$(echo "${AWS_SECRET_CONFIGS}" | tr ',' "\n")
updateFile="${DOTENV_FILE_PATH}"

mkdir -p "$(dirname "$updateFile")"
touch ${updateFile}
echo "" >> ${updateFile}

for secretId in ${secretIds}; do
  secrets=$(get_secret_value "$secretId")
  secrets=$(echo "${secrets}" | jq -r '.[] | .key + "=" + .value + ""')

  for secret in ${secrets}; do
    SECRET_KEY="$(echo ${secret} | cut -d'=' -f1)"
    grep -q "^${SECRET_KEY}=" ${updateFile} && sed -i "s#^${SECRET_KEY}=.*#${secret}#" ${updateFile} || echo ${secret} >> ${updateFile}
  done
done

echo ".env file generated Successfully"

