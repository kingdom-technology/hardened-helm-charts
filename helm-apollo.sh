#!/bin/bash -e

### USAGE:   ./helm-apollo.sh -s <service> -h <helm_chart_version> ###
### EXAMPLE: ./helm-apollo.sh -s mongodb -h 16.5.26001 ###

# Set and Check for required script
FILE=~/fedstart_token.sh
EXPIRE_SECONDS=28800 # 8 hours
if [ ! -f "$FILE" ]; then
    echo "ERROR: fedstart_token.sh script does not exist: $FILE"
    exit 1
fi

# Source APOLLO_TOKEN env var, this is a local script with the following contents "export APOLLO_TOKEN=<omitted>"
source ~/fedstart_token.sh

# Check if APOLLO_TOKEN is unset or empty
if [ -z "$APOLLO_TOKEN" ]; then
  echo "Error: APOLLO_TOKEN is not set."
  exit 1
fi

# Get current time and file modification time (in seconds since epoch)
current_time=$(date +%s)
file_mtime=$(stat -c %Y "$FILE")

# Calculate age and remaining time
time_diff=$((current_time - file_mtime))
time_remaining=$((EXPIRE_SECONDS - time_diff))

# Exit if token is expired
if [ "$time_diff" -gt $EXPIRE_SECONDS ]; then
    echo "Apollo token '$FILE' was last modified more than 24 hours ago."
    exit 100
else
    minutes_left=$((time_remaining / 60))
    echo "Apollo token at '$FILE' is still valid. It will expire in about $minutes_left minutes."
fi

VALID_SERVICES=(
  "app-sidekiq"
  "genai-image"
  "vendor-analytics"
  "vendor-pdf-service"
  "vendor-webspellchecker"
)

while getopts h:s:f:v flag; do
    case "${flag}" in
        h) helmchartversion="${OPTARG}";;
        s) service="${OPTARG}";;
        v) signimage="${OPTARG}";;
        f) FORCE=true;;
    esac
done

if [[ ! " ${VALID_SERVICES[@]} " =~ " ${service} " ]]; then
  printf "Error: Invalid service '%s'.Valid options are: %s\n" "$service" "${VALID_SERVICES[*]}"
  exit 1
fi

if [[ -z "$service" || -z "$helmchartversion" ]]; then
  echo "Usage: $0 -s <service> -h <helm_chart_version> [-f]"
  exit 1
fi

export APOLLO_URL='https://caviar-usgc-2.palantirfedstart.com/'
export AWS_ACCOUNT_ID=""
export ORGANIZATION=""
export HELM_USERNAME="AWS"
export HELM_PASSWORD="$(aws ecr get-login-password --region us-gov-west-1)"
export HELM_CHART_NAME="oci://${AWS_ACCOUNT_ID}.dkr.ecr.us-gov-west-1.amazonaws.com/helm/${service}"
export MAVEN_COORDINATE="${ORGANIZATION}:${service}:${helmchartversion}"
export HELM_CHART_REPO_URL="oci://${AWS_ACCOUNT_ID}.dkr.ecr-fips.us-gov-west-1.amazonaws.com/helm/${service}"
export HELM_CHART_VERSION="${helmchartversion}"
export AWS_REGION=us-gov-west-1
export SIGNING_PROFILE_ARN="arn:aws-us-gov:signer:us-gov-west-1:${AWS_ACCOUNT_ID}:/signing-profiles/authenticate_${ORGANIZATION}"

# Path to the Chart.yaml file
export chart_file="charts/${service}/helm-chart/Chart.yaml"
export values_file="charts/${service}/helm-chart/values.yaml"

# Check if file exists
if [ ! -f "$chart_file" ]; then
  echo "Error: File $chart_file does not exist."
  exit 1
else
  echo "Chart.yaml is found."
fi

# Update the version line in-place
sed -i "s/^version: .*/version: ${helmchartversion}/" "$chart_file"

# Create helm tar package
helm package -d chart-packages/ charts/${service}/helm-chart/

aws ecr get-login-password --region us-gov-west-1 | helm registry login   --username AWS   --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-gov-west-1.amazonaws.com

# Push to AWS ECR
helm push chart-packages/${service}-${helmchartversion}.tgz oci://${AWS_ACCOUNT_IDF}.dkr.ecr.us-gov-west-1.amazonaws.com/helm/

# Sign And Verify Images
case "$service" in
  app-sidekiq)              readyservice="appsidekiq";; 
  genai-image)              readyservice="genaiimage";;
  vendor-analytics)         readyservice="analytics";;
  vendor-pdf-server)        readyservice="formiopdf";;
  vendor-webspellchecker)   readyservice="spellchecker";; 
  *) echo "Invalid service: $SERVICE"; exit 2 ;;
esac


image_repo="$(yq -r "
  .services.${readyservice}.deployment.image.repository //
  .services.${readyservice}.deployment_nginx.image.repository //
  .deployment.image.repository //
  .deployment_nginx.image.repository //
  .image.repository // empty
" "$values_file")"

image_tag="$(yq -r "
  .services.${readyservice}.deployment.image.tag //
  .services.${readyservice}.deployment_nginx.image.tag //
  .deployment.image.tag //
  .deployment_nginx.image.tag //
  .image.tag // empty
" "$values_file")"

if [[ -z "$image_repo" || -z "$image_tag" ]]; then
  echo "ERROR: Could not determine image repository/tag from $values_file"
  exit 1
fi

if [ "$signimage" == "true" ]; then
full_image="${image_repo}:${image_tag}"
echo "Image to be signed: $full_image"

echo "Sign $full_image"
notation sign \
    --plugin com.amazonaws.signer.notation.plugin \
    --id "$SIGNING_PROFILE_ARN" \
      "$full_image"

echo "Verify $full_image"
notation verify "$full_image"
fi

apollo-cli publish helm-chart chart-packages/${service}-${helmchartversion}.tgz \
  --apollo-url "$APOLLO_URL" \
  --apollo-token "$APOLLO_TOKEN" \
  --helm-chart-name "$HELM_CHART_NAME" \
  --helm-repository-url "$HELM_CHART_REPO_URL" \
  --helm-chart-version "$HELM_CHART_VERSION" \
  --maven-coordinate "$MAVEN_COORDINATE" \
  --helm-username "$HELM_USERNAME" \
  --helm-password "$HELM_PASSWORD"

# Push changes to git
git add . && git commit -m "Updating the ${service} helm chart ${helmchartversion}" && git push