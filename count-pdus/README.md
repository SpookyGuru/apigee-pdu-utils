# count-pdus
In Apigee X, a Proxy Deployment Unit refers to a deployed API proxy or
shared flow revision within an environment and instance. Since Instances
are regional, this means a deployed proxy in an Environment attached to
two Instances counts as two Proxy Deployment Units.

This utility counts all the proxy and shared flow deployments, in all
Environments and Instances (regions), across all provided Organizations.
