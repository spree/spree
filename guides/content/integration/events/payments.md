---
title: Spree Integrator > Payments Events
---

## New Payment Event

When payment information has been collected by the store.  You can be notified by Spree Professional with a NEW PAYMENT EVENT. This event will contain all the details collected by the store.

<pre class="headers"><code>Sample: New Payment Event</code></pre>

<%= json :new_payment_event %>

The endpoint can then carry out any work needed, and must respond to the POST request with a JSON response to indicate that the message has been processed.

<pre class="headers"><code>Sample: New Payment Response</code></pre>

<%= json :new_payment_event_response %>
