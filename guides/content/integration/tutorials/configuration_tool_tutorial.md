---
title: Configuration Tool
---

## Introduction

The Spree Integrator Configuration tool is designed to make managing your Spree integrations quick and painless. Installing the tool is a simple matter of adding one line to your product's `Gemfile`, and running two commands. Once that is done, you can manage your own third-party service integrations on the fly.

## Prerequisites

This tutorial assumes that you already have [bundler](http://bundler.io/) installed and that you are familiar with basic Ruby and Rails concepts. It also assume that you already have a functioning Spree store.

## Installing spree_pro_connector

To install the configuration tool, you will need to first add the following line to your application's `Gemfile`:

```ruby
gem 'spree_pro_connector', :git => 'https://github.com/spree/spree_pro_connector.git', :branch => '2-0-stable'```

The preceding line assumes you are using the [2-0-stable branch of Spree](https://github.com/spree/spree/tree/2-0-stable). If you are using a different branch of Spree, you should then change the `:branch` value to match.

Then, open a Terminal window and run the following commands:

```bash
$ bundle install
$ bundle exec rails generate spree_pro_connector:install```

The first command installs the `spree_pro_connector` gem in your application. The second uses the gem's install generator to add Integrator-specific styles to your store's Admin Interface.

## Verifying Install Was Successful

Now when you launch your store and visit your Admin Interface by navigating to the `admin` directory, you'll notice that there is a new "Integration" tab, between the "Products" and "Configuration" tabs.

![Integration Tab](/images/integration/integration_tab.jpg)

It is here that you will establish connections to the Integrator, add and remove integrations, configure integrations, and enable and disable services.

## Configuring Integrations

There are a number of default global integrations that you can choose from as a customer of the Spree Integrator service. You can browse the [full list of global integrations](supported_integrations), including configuration and usage details for each one. For now, we will use the [Mandrill Integration](mandrill_integration) to illustrate the general usage of the Configuration tool.

### Adding an Integration

### Removing an Integration

### Configuring an Integration

### Enabling a Service

### Disabling a Service

### Disabling All Services