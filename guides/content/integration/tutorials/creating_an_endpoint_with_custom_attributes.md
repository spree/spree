---
title: Creating an Endpoint with Custom Attributes
---

## Introduction

One of the greatest things about both Spree is its flexibility. Using this full-featured open source e-commerce package means that you are total freedom to customize it to suit your business' own special needs.

The Spree Integrator extends the customizations you make in your store's schema so that you can make use of them within your third party service.

In this tutorial, you will:

* create a Spree sandbox store,
* add custom attributes to it,
* extend the store's JSON output to include the new attributes,
* create a custom endpoint for a fictional third-party service, and
* use this endpoint to access and utilize your store's custom attributes.

## Prerequisites

This tutorial assumes that you have installed [bundler](http://bundler.io/#getting-started) and [Sinatra](http://www.sinatrarb.com/intro.html), and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org).

## Creating a Sandbox Store

First, clone the spree gem:

```bash
$ git clone https://github.com/spree/spree.git
```

Then go into this new `spree` directory and run the following command to generate the sandbox app:

```bash
$ bundle exec rake sandbox
```

This creates the sandbox Spree store, complete with sample data and a default admin user, with the username **spree@example.com** and password **spree123**.

## Adding Custom Attributes to Store

## Extending JSON Output

## Creating Custom Endpoint

## Accessing Custom Data