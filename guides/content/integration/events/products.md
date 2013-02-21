---
title: Spree Professional > Product Events
---

# Product Events
Spree Professional will notify you with product movements and inventory changes. Your service can maintain inventory that is synchronized with the store.

## New Product Event
Once you have configured an endpoint url to listen for New Product Events, you will be notified when products have been added.

When a new product has been added, you will be notified with an HTTP post to the URL with a NEW_PRODUCT event:

<pre class="headers"><code>Sample: New Product Event</code></pre>
<%= json :new_product_event %>

The endpoint can then carry out any work needed, and must respond to the POST request with a JSON response to indicate that the message has been processed.

<pre class="headers"><code>Sample: New Product Response</code></pre>
<%= json :new_product_event_response %>

## Updated Product Event
Once you have configured an endpoint url to listen for Product Update Events, you will be notified when products have been changed.

When a product has been changed, you will be notified with an HTTP post to the URL with a PRODUCT_UPDATE event:

 <pre class="headers"><code>Sample: Update Product Event</code></pre>
<%= json :update_product_event %>

The endpoint can then carry out any work needed, and must respond to the POST request with a JSON response to indicate that the message has been processed.

 <pre class="headers"><code>Sample: Update Product Response</code></pre>
<%= json :update_product_event_response %>
