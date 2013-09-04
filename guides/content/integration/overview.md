---
title: Overview
---

## Introduction

The Spree Commerce hub connects your storefront to an increasing array of third-party systems and services, to help you solve the complex integration requirements of your growing e-commerce business.

The hub is a messaging system that pulls events as they happen from your storefront, and using it's customizable routing and decision layer helps to direct the messages to independent integrations.

These integrations connect to key line of business applications for accounting, logistics, customer support and much more.

## Messages

Messages are the core of the Spree Commerce hub. A single action within a storefront can result in several discrete messages being delivered to multiple integrations. Messages are represented as simple JSON documents, the following is an example of the basic message structure:

<pre class="headers"><code>Basic message structure</code></pre>
<%= json :message %>

For more details on messages please refer to the [Message Basics Guide](/integration/message_basics.html), to review specific message structures and examples please refer to the [Message Overview Guide](/integration/messages_overview.html).

## Message Flow

The hub uses a dual-queue configuration to handle the processing of messages, each received message can be fanned out to one ore more [Integrations](/integration/terminology.html#integrations) by way of [Mappings](/integration/terminology.html#mappings).

![Message Flow](/images/integration/message_flow.gif)

### Incoming Queue

As messages arrive on the hub they are stored in the incoming queue for review, each message is compared against a storefront specific mapping registry that is responsible for routing specific message types to interested Integrations.

A single message stored on the incoming queue might be mapped to multiple integrations, and a new duplicate message is pushed onto the Accepted queue for each of those integrations.

### Accepted Queue

Once a message has made it's way to the Accepted queue it's delivery to the integration's endpoint is guaranteed. The Spree Commerce support team actively monitors and troubleshoots problem messages on the accepted queue, and will contact you to help resolve any problems as they occur.

## Message Delivery

Messages are delivered to the integration's endpoint by way of a HTTP POST request what encodes the message contents as JSON. Each endpoint must respond to the request with the correct output to indicate the successful processing of the message.

![Message Delivery](/images/integration/message_delivery.gif)

### Successful Responses
Successful endpoint responses are represented by a JSON encoded HTTP 200 response, that includes the message_id of the message that was delivered to the endpoint.

### Failure Responses

Any other HTTP response code is classified as a failure, and depending on configuration the message will be automatically retried, or parked for review by a member of the support team.

