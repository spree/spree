---
title: Configuration
---

## Overview

The Spree Integrator Configuration tool is designed to make managing your Spree integrations quick and painless. It is what handles communication between your Spree store and the Spree Integrator itself.

Installing the tool is a simple matter of adding one line to your product's `Gemfile`, and running two commands. Once that is done, you can manage your own third-party service integrations on the fly.

## Prerequisites

This guide assumes you already have [bundler](http://bundler.io/) installed and that you are familiar with basic Ruby and Rails concepts. It also assume that you already have a functioning Spree store.

## Installation

Add the `spree_pro_connector` gem to your store's `Gemfile`:

```ruby
gem 'spree_pro_connector', :git => 'https://github.com/spree/spree_pro_connector.git', 
  :branch => '2-0-stable'
```

The preceding line assumes you are using the [2-0-stable branch of Spree](https://github.com/spree/spree/tree/2-0-stable). If you are using a different branch of Spree, you should then change the `:branch` value to match.

Next, run these commands:

```bash
$ bundle install
$ bundle exec rails generate spree_pro_connector:install
```

The first command installs the `spree_pro_connector` gem in your application. The second uses the gem's install generator to add Integrator-specific styles to your store's Admin Interface.

## Verifying Install Was Successful

Now when you launch your store and visit your Admin Interface by navigating to the `admin` directory, you'll notice that there is a new "Integration" tab, between the "Products" and "Configuration" tabs.

![Integration Tab](/images/integration/integration_tab.jpg)

It is here that you will establish connections to the Integrator, add and remove integrations, configure integrations, and enable and disable services.

## Making a Connection

Now that you have `spree_pro_connector` installed in your application, you need to connect it to the Spree Integrator.

***
If you have multiple stores that you maintain from the same domain, you will first need to select the store you want to make connections for before you can manage your integrations.
***

Click the "Integration" tab. The first thing you'll need to do is to select the environment for your connection. Your choices are "Custom", "Staging", and "Production".

![Choose Environment](/images/integration/choose_environment.jpg)

Once you choose your environment, your Integrator URL will be rendered, and you will be asked to log in, either as a New User or a Registered User. If this is your first time logging in, select New User; otherwise, select Registered User.

![Integrator Login](/images/integration/integrator_login.jpg)

Values for "Email", "Store Name", and "Store API URL" will already be filled in, based on what you have configured in your Spree store. You can change these if need be. Enter a value for "Password" and click the "Login" button. This will bring you to the Integration overview screen.

![Integration Overview](/images/integration/integration_overview.jpg)

## Configuration

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
* Refresh - Re-query the Spree Integrator manually to get any new information.
* Remove - Remove all of the mappings for individual services to this endpoint. Does not actually delete the integration itself, but will cause the integration not to appear on your store's "Active Integrations" section.
* Disable All - Clicking the "Enabled" button means the individual services for the integration will be disabled. The integration will still appear on your store's "Active Integrations" section.