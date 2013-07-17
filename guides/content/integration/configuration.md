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
gem 'spree_pro_connector', :git => 'https://github.com/spree/spree_pro_connector.git', :branch => '2-0-stable'
```

***
Be sure to point to the branch that matches your store's version of Spree.
***

Next, run these commands:

```bash
$ bundle install
$ bundle exec rake railties:install:migrations
$ bundle exec rake db:migrate```

Now when you go to the `/admin` section of your store and look at a particular order, you will notice under the "Return Authorizations" link a new "Order Events" link. This allows you to see any Spree Integrator events for that particular order.

![Order Events Link](/images/integration/order_events_link.jpg)

## Configuration