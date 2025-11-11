#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

# Copyright © 2024,2025 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# In Apigee X, a Proxy Deployment Unit refers to a deployed API proxy or
# shared flow revision within an environment and instance. Since Instances
# are regional, this means a deployed proxy in an Environment attached to
# two Instances counts as two Proxy Deployment Units.
#
# This script counts all the proxy and shared flow deployments, in all
# Environments and Instances (regions), across all provided Organizations.

# Treat unset variables as an error.
set -u
# Ensure that pipeline failures are not ignored.
set -o pipefail

# --- Configuration ---
API_BASE="https://apigee.googleapis.com/v1"

# --- Dependency Check ---
if ! command -v curl &> /dev/null; then
    echo "Error: 'curl' is not installed. Please install it to continue."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to continue."
    exit 1
fi

# --- Input Validation ---
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <AUTH_TOKEN> <org1_name> [org2_name] ..."
    echo "Example: $0 \$(gcloud auth print-access-token) my-org-1 my-org-2"
    exit 1
fi

TOKEN="$1"
shift # Remove the token from the argument list
ORGS=("$@") # The rest of the arguments are organization names

# Create a reusable Authorization Header
AUTH_HEADER="Authorization: Bearer $TOKEN"

# Start a counter to count all PDUs across all Organizations
TOTAL_PDU_COUNT=0

# Loop through each Organization passed in
for ORG in "${ORGS[@]}"; do
    
    # --- Output the Organization name ---
    echo -e "\n## Organization: $ORG"
    
    # --- Get a list of Environments for this Organization ---
    # The API returns a simple JSON array of environment names, e.g., ["prod", "test"]
    ENVS_JSON=$(curl -s --fail-with-body -H "$AUTH_HEADER" "${API_BASE}/organizations/${ORG}/environments")
    RETURN_CODE=$?

    # Check the curl return code. Since this is the first call, it will probably be the most like to fail
    if [ $RETURN_CODE -ne 0 ]; then
        echo "Error getting Environments: curl command failed with exit status $RETURN_CODE"
        echo "curl output: $ENVS_JSON"
	exit 1
    fi

    # Check if any environments were returned
    if [ -z "$ENVS_JSON" ] || [ "$(echo "$ENVS_JSON" | jq 'length')" -eq 0 ]; then
        echo "  No environments found or API call failed for $ORG."
        continue # Skip to the next organization
    fi

    # Create an array to count the number of Instances (regions) an Environment is attached to
    declare -A ATTACHMENT_COUNTS

    # For each Environment, set the Attachment Count to initially Zero  ---
    while read -r ENV; do
        ATTACHMENT_COUNTS[$ENV]=0
    done < <(echo "$ENVS_JSON" | jq -r '.[]')

    # Get a list of Instances ---
    INSTANCES_JSON=$(curl -s -H "$AUTH_HEADER" "${API_BASE}/organizations/${ORG}/instances")

    # Check if any instances were returned
    if [ -z "$INSTANCES_JSON" ] || [ "$(echo "$INSTANCES_JSON" | jq 'length')" -eq 0 ]; then
        echo "  No Instances found or API call failed for $ORG."
        continue # Skip to the next organization
    fi

    # Extract just the instance names
    INSTANCES=$( jq -r '.[] | map(.name)' <<< "${INSTANCES_JSON}")

    # For each Instance, see what Environments are attached and keep count
    while read -r INSTANCE; do

	# Get a list of Attachments
	ATTACHMENTS_JSON=$(curl -s -H "$AUTH_HEADER" "${API_BASE}/organizations/${ORG}/instances/${INSTANCE}/attachments") 

	# Check if any environments were returned
        if [ -z "$ATTACHMENTS_JSON" ] || [ "$(echo "$ATTACHMENTS_JSON" | jq 'length')" -eq 0 ]; then
            echo "  No attachments found or API call failed for Instance $INSTANCE."
            continue # Skip to the next Instance
        fi

        # For each Attachment, get its environments
        ATTACHMENT_ENVS=$( jq -r '.[] | map(.environment)' <<< "${ATTACHMENTS_JSON}")

	# For each Attached Environment, increment the Attachemnt Counter
	while read -r ATTACH_ENV; do

            # Increment the counter array
            if [[ -v ATTACHMENT_COUNTS["$ATTACH_ENV"] ]]; then
		((ATTACHMENT_COUNTS["$ATTACH_ENV"]=${ATTACHMENT_COUNTS["$ATTACH_ENV"]}+1))
            else
                # Found attachment for unlisted environment, so just set it to one 
                ATTACHMENT_COUNTS["$ATTACH_ENV"]=1
            fi
        done < <(echo "$ATTACHMENT_ENVS" | jq -r '.[]')
    done < <(echo "$INSTANCES" | jq -r '.[]')

    # Start the Org's PDU count at zero
    ORG_PDU_COUNT=0

    # For each Environment, calulate the PDUs
    while read -r ENV; do

	# Get and Count Proxy deployments (sharedFlows=false)
        # The API returns {"deployments": [...]}. We count the elements in the array.
        # The '// 0' in jq ensures we get 0 instead of 'null' if 'deployments' is missing.
        PROXY_COUNT=$(curl -s -H "$AUTH_HEADER" \
            "${API_BASE}/organizations/${ORG}/environments/${ENV}/deployments?sharedFlows=false" | jq '.deployments | length // 0')

	# Get and Count Shared Flow deployments (sharedFlows=true)
        SF_COUNT=$(curl -s -H "$AUTH_HEADER" \
            "${API_BASE}/organizations/${ORG}/environments/${ENV}/deployments?sharedFlows=true" | jq '.deployments | length // 0')

	# Calculate the PDU count for this Environment (Total Deployments multiplied by the number of Instances [regions])
	((PDU_COUNT=($PROXY_COUNT+$SF_COUNT)*${ATTACHMENT_COUNTS[$ENV]}))

	# Add this Env's PDU count to the Org's PDU count
	((ORG_PDU_COUNT+=$PDU_COUNT))

        # Output the counts for the Env
        # Using printf for clean, aligned formatting.
        printf "  - Env: %-25s | Regions: %-5s | Proxies: %-5s | SharedFlows: %-5s | PDU Count: %-6s\n" "$ENV" "${ATTACHMENT_COUNTS[$ENV]}" "$PROXY_COUNT" "$SF_COUNT" "$PDU_COUNT"
        
    done < <(echo "$ENVS_JSON" | jq -r '.[]')

    # Output the counts for the Org
    echo "Total PDU Count for Org ${ORG}: ${ORG_PDU_COUNT}"
    ((TOTAL_PDU_COUNT+=$ORG_PDU_COUNT))
done

# Output the counts for the entire list of Orgs
echo -e "\nTotal PDU Count for All Orgs: ${TOTAL_PDU_COUNT}"

echo -e "\nDone."
