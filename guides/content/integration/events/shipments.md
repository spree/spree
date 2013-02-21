---
title: Spree Integration > Shipment Events
---

# Shipment Events

This guide explains the two events that maybe consumed relating to shipments:

* TOC
{:toc}

## Shipment Ready Event

In this example, a payment has just been captured on a store which results in a "Shipment Ready" event being created.

The integrator has already configured an endpoint for "Shipment Ready" events, so the following JSON is POST'ed to that URL.

<pre class="headers"><code>Sample: Shipment Ready Message</code></pre>
<%= json :shipment_ready_event %>

As you can see the message includes all the details relating to the shipment.

The endpoint can then carry out any work needed, and must respond to the POST request with a JSON response to indicate that the message has been processed.

<pre class="headers"><code>Sample: Shipment Ready Response</code></pre>
<%= json :shipment_ready_response %>

Optionally, the endpoint can include event details what will be displayed alongside the shipment within the Spree administration interface.

## Shipment Confirmed Event

In this example, a shipment has just been dispatched which results in a "Shipment Confirmed" event being created.

The integrator has already configured an endpoint for "Shipment Confirmed" events, so the following JSON is PUT'ed to that URL.

<pre class="headers"><code>Sample: Shipment Confirmation Message</code></pre>
<%= json :shipment_confirmation_event %>

As you can see the message includes all the details relating to the shipment.

The endpoint can then carry out any work needed, and must respond to the PUT request with a JSON response to indicate that the message has been processed.

<pre class="headers"><code>Sample: Shipment Confirmation Response</code></pre>
<%= json :shipment_confirmation_response %>

Optionally, the endpoint can include event details what will be displayed alongside the shipment within the Spree administration interface.
