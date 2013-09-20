---
title: Connecting your endpoint
---

## Overview

Once you've created your endpoint you'll want to connect it to the hub so it can start processing messages. This guides explains:

1. Adding an `endpoint.json` file for your endpoint.

2. Deploying your endpoint and configuring the security.

3. Registering your endpoint with the hub using the spree_hub_connector gem.


## endpoint.json

When configuring an Integration using the Spree Hub Connector the information from the `endpoint.json` is used to populate a [mapping](/integration/mapping_basics.html) with default configuration for each configured service.

The file contains some basic details about your endpoint and lists all the available services including which messages you recommend the service to process and all configuration details (like parameters, filters, identifiers that the service may require).

The `endpoint.json` file must be available at the root path of your application via `HTTP GET` request i.e. /endpoint.json

For more details on the contents of the file please refer to the [Custom Integrations](/integration/custom_integrations.html) guide.

## Deployment and Security

All endpoints must be publicly accessible in order for the hub to be able to route messages to it successfully. All production endpoints must be deployed on SSL secured hosts.

To ensure your endpoint only processes messages from the hub you must configure a preshared key that the hub will include as a HTTP header with each message it delivers.

If you've used the Endpoint Base library to create your endpoint then security checks are already built-in and you just need to configure the `ENDPOINT_KEY` environment variable with a 32 digit (or longer) secret token of your choosing.

## Registering your endpoint.

Once your endpoint has been deployed, and the `ENDPOINT_KEY` has been configured you are now ready to register your endpoint with the hub. You will need the following details:

1. **URL** - Fully qualified domain name of the application.
2. **Name** - The name of the endpoint (as contained in the `endpoint.json` file).
3. **Token** - The 32 digit value you chose as your `ENDPOINT_KEY`

#TODO: Show steps to register with screenshots.
