---
title: Configuration
---

## Overview

The `spree_pro_connector` is at the heart of the Spree Integrator service. It is what handles communication between your Spree store and the Spree Integrator itself. This guide will instruct you on the installation and configuration of this tool.

## Prerequisites

This guide assumes you already have [bundler](http://bundler.io/) installed and that you are familiar with basic Ruby and Rails concepts. It also assume that you already have a functioning Spree store.

## Installation

Add the `spree_pro_connector` gem to your store's `Gemfile`:

```ruby
gem 'spree_pro_connector', :git => 'https://github.com/spree/spree_pro_connector.git', :branch => '2-0-stable'```

***
Be sure to point to the branch that matches your store's version of Spree.
***

Next, run these commands:

```bash
$ bundle install
$ bundle exec rails generate spree_pro_connector:install```

Now when you go to the `/admin` section of your store, you will see a new "Integration" tab between the "Products" and "Configuration" tabs. This is where you will configure your store's integrations.

![Integration Tab](/images/integration/integration_tab.jpg)

## Configuration
