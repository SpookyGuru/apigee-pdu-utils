# apigee-pdu-utils
This project is for utilities to working with Apigee Proxy Deployment Units

In [Apigee](https://cloud.google.com/apigee), a [Proxy Deployment Unit (PDU)](https://docs.cloud.google.com/apigee/docs/api-platform/fundamentals/environments-overview#proxy-deployment-units) is the metric used to count each active revision of an API proxy or a shared flow deployed to an environment within a specific region. It is a factor in how Apigee usage is licensed and billed (either via subscription plans or pay-as-you-go).

In the Google Cloud Console, you can [view your PDU usage](https://docs.cloud.google.com/apigee/docs/api-platform/deploy/ui-deploy-overview#view-proxy-deployment-usage) for your project.  If you have a complicated environment or instance configuration, the [count-pdus](./count-pdus/) utility will help clarify how the PDU count was calculated.