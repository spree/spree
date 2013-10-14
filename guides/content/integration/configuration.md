---
title: Configuration
---

## Overview

The SpreeCommerce hub configuration tool is designed to make managing your Spree integrations quick and painless. It is what handles communication between your storefront and the SpreeCommerce hub itself.

Installing the tool is a simple matter of adding one line to your product's `Gemfile`, and running two commands. Once that is done, you can manage your own third-party service integrations on the fly.

## Prerequisites

This guide assumes you already have [bundler](http://bundler.io/) installed and that you are familiar with basic Ruby and Rails concepts. It also assumes that you already have a functioning Spree storefront.

## Installation

Add the `spree_hub_connector` gem to your store's `Gemfile`:

```ruby
gem 'spree_hub_connector', github: 'spree/spree_hub_connector', branch: '2-0-stable'
```

The preceding line assumes you are using the [2-0-stable branch of Spree](https://github.com/spree/spree/tree/2-0-stable). If you are using a different branch of Spree, you should then change the `:branch` value to match.

Next, run these commands:

```bash
$ bundle install
$ bundle exec rails generate spree_hub_connector:install
```

The first command installs the `spree_hub_connector` gem in your application. The second uses the gem's install generator to add hub-specific styles, and ActiveRecord migrations to your Spree application.

## Verifying Install Was Successful

Now when you launch your store and visit your Admin Interface by navigating to the `/admin` url, you'll notice that there is a new "Integration" tab, between the "Products" and "Configuration" tabs.

![Integration Tab](/images/integration/integration_tab.jpg)

It is here that you will establish connections to the SpreeCommerce hub, add and remove integrations, configure integrations, and enable and disable services.

## Making a Connection

Now that you have `spree_hub_connector` installed in your application, you need to connect it to the SpreeCommerce hub.

***
If you have multiple stores that you maintain from the same domain, you will first need to select the store you want to make connections for before you can manage your integrations.
***

Click the "Integration" tab. The first thing you'll need to do is to select the environment for your connection. Your choices are "Custom", "Staging", and "Production".

![Choose Environment](/images/integration/choose_environment.jpg)

Once you choose your environment, your hub URL will be displayed, and you will be asked to log in, either as a New User or a Registered User. If this is your first time logging in, select New User; otherwise, select Registered User.

![Integrator Login](/images/integration/integrator_login.jpg)

Values for "Email", "Store Name", and "Store API URL" will already be filled in, based on what you have configured in your Spree store. You can change these if need be. Enter a value for "Password" and click the "Login" button. This will bring you to the Integration overview screen.

![Integration Overview](/images/integration/integration_overview.jpg)

## Adding Integrations

### Standard Integrations

When you expand the "Add New Integration" drop-down menu, you'll see a list of all of the globally-available integrations. You should review the particular configuration details for any of the [supported integrations](supported_integrations) you want to use, but we'll use [Mandrill](mandrill_integration) as an example to understand how the Configuration tool is used generally.

![Mandrill Configuration](/images/integration/mandrill_config.jpg)

To the left of the configuration window are the endpoint's services. For the Mandrill endpoint, those services include:

* Order_Confirmation
* Order_Cancellation
* Shipment_Confirmation

By default, each service is disabled. Click on the "Disabled" state button to enable a service, so you can enter its necessary parameters.

***
Creating an integration does not mean you need to enable and use all of its services; you can choose to enable only those you want.
***

Once you have properly enabled and configured any of the endpoint's services you want to use, click the "Save" button. The Overview page refreshes, and you now see your newly-configured integration listed in the "Active Integrations" section.

![Active Integrations](/images/integration/active_integrations.jpg)

By hovering over the buttons on this integration, you see that you have several options for actions you can take:

* Edit Properties - Re-open the configuration window, enable/disable individual services, change parameters for a service.
* Refresh - Re-query the SpreeCommerce hub manually to get any new information.
* Remove - Remove all of the mappings for individual services to this endpoint. Does not actually delete the integration itself, but will cause the integration not to appear on your store's "Active Integrations" section.
* Disable All - Clicking the "Enabled" button means the individual services for the integration will be disabled. The integration will still appear on your store's "Active Integrations" section.

### Custom Integrations

#### Overview

***
For more information on building a custom endpoint, please follow the [Custom Endpoint tutorial](basic_endpoints_tutorial).
***

Once you've created your endpoint you'll want to connect it to the hub so it can start processing messages. We'll go over:

1. Adding an `endpoint.json` file for your endpoint.

2. Deploying your endpoint and configuring the security.

3. Registering your endpoint with the hub using the spree_hub_connector gem.

#### endpoint.json

When configuring an Integration using the Spree Hub Connector the information from the `endpoint.json` is used to populate a [mapping](/integration/mapping_basics.html) with default configuration for each configured service.

The file contains some basic details about your endpoint and lists all the available services including which messages you recommend the service to process and all configuration details (like parameters, filters, identifiers that the service may require).

The `endpoint.json` file must be available at the root path of your application via `HTTP GET` request i.e. /endpoint.json

For more details on the contents of the file please refer to the [Custom Integrations](/integration/custom_integrations.html) guide.

#### Deployment and Security

All endpoints must be publicly accessible in order for the hub to be able to route messages to it successfully. All production endpoints must be deployed on SSL secured hosts.

To ensure your endpoint only processes messages from the hub you must configure a preshared key that the hub will include as a HTTP header with each message it delivers.

If you've used the Endpoint Base library to create your endpoint then security checks are already built-in and you just need to configure the `ENDPOINT_KEY` environment variable with a 32 digit (or longer) secret token of your choosing.

#### Registering your endpoint.

Once your endpoint has been deployed, and the `ENDPOINT_KEY` has been configured you are now ready to register your endpoint with the hub. You will need the following details:

1. **URL** - Fully qualified domain name of the application.
2. **Name** - The name of the endpoint (as contained in the `endpoint.json` file).
3. **Token** - The 32 digit value you chose as your `ENDPOINT_KEY`

When you expand the "Add New Integration" drop-down menu, you'll see an option to add a custom integration. You can choose this option in order to add an integration for an endpoint that is not in the list of globally available integrations.

After selecting the "Add Custom" option, you will see a form that allows you to fill in your endpoint details and create the new integration.

![Adding A Custom Integration](/images/integration/add_custom_integration.jpg)

Once you have filled out this form, click the "Save" button. The Overview page will update and you will see your custom integration listed in the "Active Integrations" section in the pending state.

![Pending Custom Integration](/images/integration/pending_custom_integration.jpg)

The integration is initially in the pending state while the hub pulls down your endpoint's services from the `endpoint.json` file. While in this state, you can click on the "Edit Properties" option beneath your integration in the Active Integrations list to view it's current status.

Initially you will see a message that tells you to wait while the endpoint configuration is fetched.

![Pending Integration Being Fetched](/images/integration/fetch_custom_integration.jpg)

If there are any errors in your endpoint's `endpoint.json` file this screen will automatically update and list the errors.

![Custom Integration With Errors](/images/integration/errors_custom_integration.jpg)

Once you fix any `endpoint.json` errors that may be present, the integration will be updated and you will be able to configure it exactly like any other global integration.

If you ever need to update the endpoint information for a custom integration, click on the gear icon beneath you integration in the Active Integrations list. This will allow you to edit the endpoint's name, url, or token.
