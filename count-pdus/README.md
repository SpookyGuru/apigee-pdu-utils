# count-pdus

In [Apigee](https://cloud.google.com/apigee), a [Proxy Deployment Unit (PDU)](https://docs.cloud.google.com/apigee/docs/api-platform/fundamentals/environments-overview#proxy-deployment-units) is the metric used to count each active revision of an API proxy or a shared flow deployed to an environment within a specific region.  This means a proxy or shared flow deployed to an Environment attached to two Instances counts as two Proxy Deployment Units.

This utility counts all the proxy and shared flow deployments, in all Environments and Instances (regions), across all provided Organizations.

# Usage
The script uses your supplied token to make API calls to retrieve the deployment counts. The only other argument is one or more Apigee Organization names (GCP Project IDs).  The simplest way to invoke the script is by using the gcloud command to assign the access token to a variable, like this:

```
TOKEN="$(gcloud auth print-access-token)"

./countPDUs.sh $TOKEN orgName1 [orgName2 ... orgNameN]
```

Output will show each Organization, with details of the deployments for each Environment.  Summary counts are shown for the Organizations and total across all provided Organizations.

## Examples
```
TOKEN="$(gcloud auth print-access-token)"

./countPDUs.sh $TOKEN my-org-1 my-org-2
```
Will produce output similar to this:
```
## Organization: my-org-1
  - Env: dev                       | Regions: 2     | Proxies: 33    | SharedFlows: 2     | PDU Count: 70    
  - Env: dev-config                | Regions: 0     | Proxies: 0     | SharedFlows: 0     | PDU Count: 0     
  - Env: dev1                      | Regions: 1     | Proxies: 28    | SharedFlows: 1     | PDU Count: 29    
Total PDU Count for Org my-org-1: 99

## Organization: my-org-2
  - Env: operator-env              | Regions: 1     | Proxies: 2     | SharedFlows: 1     | PDU Count: 3     
  - Env: default-dev               | Regions: 2     | Proxies: 71    | SharedFlows: 29    | PDU Count: 200   
  - Env: east-dev                  | Regions: 1     | Proxies: 1     | SharedFlows: 0     | PDU Count: 1     
  - Env: local-dev                 | Regions: 0     | Proxies: 1     | SharedFlows: 1     | PDU Count: 0     
  - Env: prod                      | Regions: 2     | Proxies: 3     | SharedFlows: 19    | PDU Count: 44    
  - Env: my-other-dev              | Regions: 1     | Proxies: 0     | SharedFlows: 0     | PDU Count: 0     
Total PDU Count for Org my-org-2: 248

Total PDU Count for All Orgs: 347
```
