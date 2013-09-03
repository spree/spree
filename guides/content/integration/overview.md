---
title: Overview
---

## Introduction

The Spree Commerce hub connects your storefront to an increasing array of third-party systems and services, to help you solve the complex integration requirements required by your growing e-commerce business.

The hub is a messaging system that pulls events as they happen from your storefront, and using it's customizable routing and decision layer helps to direct the messages to independent integrations.

These integrations connect to key line of business applications for accounting, logistics, customer support and much more.

## Message Flow

The hub uses a dual-queue configuration to handle the processing of messages, each received message is fanned out to any or all interesting parties.

![Message Flow](/images/integration/message_flow.gif)

### Incoming Queue

As messages arrive on the hub they are stored in the incoming queue for review, each message is compared against a storefront specific mapping registry that is responsible for routing specific message types to interested Integrations.

A single message stored on the incoming queue might be mapped to multiple integrations, and a new duplicate message is pushed onto the Accepted queue for each integration.

### Accepted Queue

Once a message has made it's way to the Accepted queue it's delivery to the integration's endpoint is guaranteed. Message are delivered to the integration endpoint by way of a HTTP POST request what encodes the message contents as JSON. Each endpoint must respond to the request with the correct output to indicate the successful processing of the message.

The Spree Commerce support team actively monitors and troubleshoots problem messages on the accepted queue, and will contact you to help resolve any problems as they occur.




