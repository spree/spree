---
title: Returning Parameters From an Endpoint
---

There may be times when you need to return more from an endpoint than just a message status code and a message description. For example, you might need to pass back a refreshed authentication token from a service that uses OAuth and have the Hub store the refreshed token. You might need to pass back a shipment confirmation number from your fulfillment service so that your store can be updated with this information. The Hub has an easy, built-in technique for dealing with these types of situations.

## Prerequisites

This tutorial is an extension of the code used in the [Fulfillment Integration Tutorial](fulfillment_integration_tutorial) and is available on [Github](https://github.com/spree/integration_tutorials/tree/master/return_params). This tutorial assumes that you have [installed bundler](http://bundler.io/#getting-started) and Sinatra, and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org).

