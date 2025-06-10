#! /bin/bash

set -euo pipefail

PRG=$(basename -- "${0}")

USAGE="
usage:	${PRG}
        [--help]

        Prerequsites:
        - git
        - curl
        - jq
        - yq
        - ibmcloud CLI
        - ibmcloud catalog CLI plugin

        Required environment variables:
        GH_TOKEN  (github token used to clone offering repo)
        CLOUD_API_KEY  (apikey with access to the catalog)
        PIPELINE_RUN_URL (url of pipeline run to refer in github issues)

        Required arguments:
        --repo_name=<repo-name>
        --offering_name=<offering-name>
        --release_notes_link=,release-notes-link>
        --env=<env>
        
        Optional arguments:
        --version=<version>  (if no value passed, the current latest git release tag will be used. Value must be passed if using --github_branch)
        --github_branch=<branch-name>  (use if you want to import code from a branch)
        --github_url=<github_url>  (allowed values are 'github.com' or 'github.ibm.com' - defaults to 'github.com' if not passed)
        --github_org=<github-org>  (defaults to 'terraform-ibm-modules')
        --catalog_yaml=<branch-name>  (If not set, code will use the yaml from the repos primary branch)
        --new_version=<new-version>
"

# set -x  # Enable tracing for debugging
# trap 'echo "[ERROR] Command failed at line $LINENO: $BASH_COMMAND"' ERR

###############################################################################
# Script: release.sh
# Description:
#   - Parses parameters and environment
#   - Clones GitHub repo
#   - Extracts catalog & offering info
#   - Creates CR via change_request.sh
#   - Marks version as ready (if enabled)
#   - Marks CR as implemented & closes it
#
# Required ENV:
#   CLOUD_API_KEY  - IBM Cloud API Key
#   GH_TOKEN       - GitHub token for cloning
###############################################################################
# GLOBAL VARIABLES

CATALOG_JSON_FILENAME="ibm_catalog.json"
# ----------- Parse CLI Arguments -----------
for arg in "$@"; do
  set +e
  found_match=false

  if echo "${arg}" | grep -q -e --new-version=; then
    NEW_VERSION=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  if echo "${arg}" | grep -q -e --release-notes-link=; then
    RELEASE_NOTES_LINK=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  if echo "${arg}" | grep -q -e --env=; then
    ENV=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  # if echo "${arg}" | grep -q -e --offering-name=; then
  #   OFFERING_NAME=$(echo "${arg}" | awk -F= '{ print $2 }')
  #   export OFFERING_NAME
  #   found_match=true
  # fi
  if echo "${arg}" | grep -q -e --version=; then
    VERSION=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  if echo "${arg}" | grep -q -e --repo-name=; then
    REPO_NAME=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  if echo "${arg}" | grep -q -e --github-branch=; then
    GITHUB_BRANCH=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  if echo "${arg}" | grep -q -e --github-org=; then
    GITHUB_ORG=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  if echo "${arg}" | grep -q -e --github-url=; then
    GITHUB_URL=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi
  if echo "${arg}" | grep -q -e --catalog-yaml=; then
    CATALOG_YAML=$(echo "${arg}" | awk -F= '{ print $2 }')
    found_match=true
  fi

  if [ "${found_match}" = false ]; then
    if [ "${arg}" != "--help" ]; then
      echo "[ERROR] Unknown command line argument: ${arg}"
    fi
    echo "${USAGE}"  
    exit 1
  fi
  set -e
done

echo "github_url: ${GITHUB_URL}"
echo "github_org: ${GITHUB_ORG}"
if [ -n "${GITHUB_BRANCH}" ]; then
  echo "github_branch: ${GITHUB_BRANCH}"
fi

# Verify required environment variables are set
all_env_vars_exist=true
env_var_array=( GH_TOKEN CLOUD_API_KEY PIPELINE_RUN_URL )
set +u
for var in "${env_var_array[@]}"; do
  [ -z "${!var}" ] && echo "$var not defined." && all_env_vars_exist=false
done
set -u
if [ ${all_env_vars_exist} == false ]; then
  echo
  echo "One or more required environment variables are not defined. See usage below:"
  echo "${USAGE}"
  exit 1
fi
# if [ -z "${OFFERING_NAME}" ]; then
#  echo
#   echo "Missing value for required arg --offering_name. See usage below:"
#   echo "${USAGE}"
#   exit 1
# fi
# Verify required args set
if [ -z "${REPO_NAME}" ]; then
  echo
  echo "Missing value for required arg --repo_name. See usage below:"
  echo "${USAGE}"
  exit 1
fi
if [ -z "${RELEASE_NOTES_LINK}" ]; then
 echo
  echo "Missing value for required arg --release-notes-link. See usage below:"
  echo "${USAGE}"
  exit 1
fi
if [ -z "${CATALOG_YAML}" ]; then
 echo
  echo "Missing value for required arg --catalog_yaml. See usage below:"
  echo "${USAGE}"
  exit 1
fi
if [ -z "${ENV}" ]; then
 echo
  echo "Missing value for required arg --env. See usage below:"
  echo "${USAGE}"
  exit 1
fi
# Verify github url value
if [ "${GITHUB_URL}" != "github.ibm.com" ] && [ "${GITHUB_URL}" != "github.com" ]; then
  echo
  echo "--github_url value must be github.ibm.com or github.com. See usage below:"
  echo "${USAGE}"
  exit 1
fi
if [ -z "${GITHUB_ORG}" ]; then
 echo
  echo "Missing value for required arg --github_org. See usage below:"
  echo "${USAGE}"
  exit 1
fi
# Verify github branch value
if [ -n "${GITHUB_BRANCH}" ] && [ -z "${VERSION}" ]; then
  echo
  echo "--version value must be passed when using the --github_branch arg. See usage below:"
  echo "${USAGE}"
  exit 1
fi

# determine branch / version
if [ -n "${GITHUB_BRANCH}" ]; then
  BRANCH="${GITHUB_BRANCH}"
else
  if [ -z "${VERSION}" ]; then
    echo "Version was not passed using --version arg, so attempting to use latest github release tag.."
    VERSION=$(curl --retry 3 -fLsS \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: token ${GH_TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.${GITHUB_URL}/repos/${GITHUB_ORG}/${REPO_NAME}/releases/latest" | jq -r .tag_name)
    if [ "${VERSION}" == "null" ]; then
      echo "Unable to detect latest git release tag. Ensure a git release exists, or use --github_branch and --version to use a branch and create a new version in catalog"
      exit 1
    fi
  fi
  BRANCH="${VERSION}"
fi
echo "version: ${VERSION}"
# ----------- Defaults -----------

PIPELINE_YAML="${CATALOG_YAML:-.catalog-onboard-pipeline.yaml}"
WORKDIR="$(mktemp -d)"

OFFERING_JSON="$WORKDIR/offering.json"

# --- IBM Cloud API endpoint ---
if [[ "$ENV" == "test" ]]; then
    CLOUD_API="https://test.cloud.ibm.com"
else
    CLOUD_API="https://cloud.ibm.com"
fi

# # --- IBM Cloud Login ---
echo "[INFO] Logging into IBM Cloud..."
ibmcloud login -a "https://cloud.ibm.com" -r "$REGION" -q --apikey "$CLOUD_API_KEY"
# Log into catalog account with CLI
  # echo
  # echo "Logging into catalog account.."
  # ic_login "${CLOUD_API_KEY}"


# --- Auto-detect resource group ---
# echo "[INFO] Detecting resource groups..."
# RESOURCE_GROUP=$(ibmcloud resource groups --output json | jq -r '.[0].name')
# if [[ -z "$RESOURCE_GROUP" || "$RESOURCE_GROUP" == "null" ]]; then
#     echo "[ERROR] No resource groups found. Check your API key permissions."
#     exit 1
# fi
# ibmcloud target -g "$RESOURCE_GROUP"
# echo "[INFO] Targeted resource group: $RESOURCE_GROUP"

# create netrc
echo -e "machine ${GITHUB_URL}\n  login ${GH_TOKEN}" >> ~/.netrc

# ----------- Clone GitHub Repository -----------

# clone repo
rm -rf "${REPO_NAME}"
echo
git clone --recurse-submodules -c advice.detachedHead=false -b "${BRANCH}" "https://username:${GH_TOKEN}@${GITHUB_URL}/${GITHUB_ORG}/${REPO_NAME}.git"
echo "Successfully cloned repo."

# VALIDATE PIPELINE CONFIG                                                                                                                        


# verify .catalog-onboard-pipeline.yaml exist in the repo
PIPELINE_YAML_PATH="$REPO_NAME/$PIPELINE_YAML"
if [[ ! -f "$PIPELINE_YAML_PATH" ]]; then
  echo "[ERROR] Pipeline YAML $PIPELINE_YAML not found at $PIPELINE_YAML_PATH"
  exit 1
fi
echo "[INFO] Found pipeline YAML: $PIPELINE_YAML_PATH"



# ----------- Extract Offering Metadata -----------
OFFERING_NAME="${OFFERING_NAME:-$(yq -r '.offerings[1].name' "$PIPELINE_YAML_PATH")}"
KIND=$(yq -r '.offerings[] | select(.name == env(OFFERING_NAME)) | .kind' "$PIPELINE_YAML_PATH")
echo "[INFO] Detected offering name: $OFFERING_NAME"
echo "[INFO] Detected offering kind: $KIND"

if [[ "$KIND" == "solution" ]]; then
    variation_array_name="variations"
else
    variation_array_name="examples"
fi
array_position="${array_position:-0}"

## Extracting catalog and offering id from yaml file
CATALOG_ID=$(yq eval '.offerings[] | select(.name == env(OFFERING_NAME)) | .catalog_id' "$PIPELINE_YAML_PATH")
OFFERING_ID=$(yq eval '.offerings[] | select(.name == env(OFFERING_NAME)) | .offering_id' "$PIPELINE_YAML_PATH")

if [[ -z "$CATALOG_ID" || "$CATALOG_ID" == "null" ]]; then
    echo "[ERROR] catalog_id not found in pipeline YAML"
    exit 1
fi
if [[ -z "$OFFERING_ID" || "$OFFERING_ID" == "null" ]]; then
    echo "[ERROR] offering_id not found in pipeline YAML"
    exit 1
fi

echo "[INFO] Extracted catalog_id: $CATALOG_ID"
echo "[INFO] Extracted offering_id: $OFFERING_ID"

# --- Fetch Offering JSON Metadata ---
echo "[INFO] Fetching offering metadata JSON..."
ibmcloud catalog offering get --catalog "$CATALOG_ID" --offering "$OFFERING_ID" --output json >"$OFFERING_JSON"

# ----------- Call change_request.sh to Create CR -----------

source ./change_request.sh 
create_cr "$SERVICE_NAME"


CR_NUMBER=$(cat /tmp/cr_number)
echo "[INFO] CR created: $CR_NUMBER"

# ----------- Fetch Offering JSON -----------
ibmcloud catalog offering get --catalog "$CATALOG_ID" --offering "$OFFERING_ID" --output json >"$OFFERING_JSON"

# ----------- Resolve Version If Not Supplied -----------
if [[ -z "${VERSION:-}" ]]; then
    VERSION=$(jq -r '[.kinds[].versions[] | select(.state.current == "validated")] | sort_by(.version) | reverse | .[0].version' "$OFFERING_JSON")
    echo "[INFO] Resolved latest validated version: $VERSION"
fi

# ----------- Get Version Locator -----------
VERSION_LOCATOR=$(jq -r --arg v "$VERSION" '.kinds[].versions[] | select(.version == $v) | .version_locator' "$OFFERING_JSON")
if [[ -z "$VERSION_LOCATOR" || "$VERSION_LOCATOR" == "null" ]]; then
    echo "[ERROR] version_locator not found for version $VERSION"
    exit 1
fi

echo "[INFO] Found version_locator: $VERSION_LOCATOR"

# ----------- Mark CR as Implemented -----------

mark_cr_implemented "$CR_NUMBER"

# ----------- Mark Ready if Configured checking -----------
# echo "[INFO] Evaluating mark_ready..."
# echo "[INFO] YAML path: .offerings[] | select(.name == \"$OFFERING_NAME\") | .[\"$variation_array_name\"][$array_position].mark_ready"
# mark_ready=$(yq -r ".offerings[] | select(.name == \"$OFFERING_NAME\") | .[\"$variation_array_name\"][$array_position].mark_ready" "$PIPELINE_YAML_PATH")

# if [[ -z "$mark_ready" ]]; then
#     echo "[ERROR] Could not extract mark_ready from YAML. Check OFFERING_NAME, KIND, or array position."
#     exit 1
# elif [[ "$mark_ready" != "true" && "$mark_ready" != "false" ]]; then
#     echo "[ERROR] Invalid 'mark_ready' value: $mark_ready. Must be true or false."
#     exit 1
# fi

echo "[INFO] mark_ready = $mark_ready"

if [[ "$mark_ready" == "true" ]]; then
    echo "[INFO] Marking version $VERSION as ready to publish (consumable)..."
    #ibmcloud catalog offering version update --version-locator "$VERSION_LOCATOR" --target-state consumable
    ibmcloud catalog offering ready --version-locator $VERSION_LOCATOR
    NEW_STATE=$(ibmcloud catalog offering get --catalog "$CATALOG_ID" --offering "$OFFERING_ID" --output json | jq -r --arg v "$VERSION" '.kinds[].versions[] | select(.version == $v) | .state.current')
    echo "[INFO] Updated version state: $NEW_STATE"
    if [[ "$NEW_STATE" == "consumable" ]]; then
        echo "[SUCCESS] Version $VERSION is now ready to publish."
    else
        echo "[ERROR] Failed to update version $VERSION to consumable. Current state: $NEW_STATE"
        exit 1
    fi
else
    echo "[INFO] 'mark_ready' is false. Skipping publish readiness."
fi

echo "[INFO] Done."

# ----------- Close the Change Request -----------
close_cr "$CR_NUMBER"
