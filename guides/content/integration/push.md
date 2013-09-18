---
title: Pushing Messages
---

## Pushing Messages

External systems can push messages on to the Integrators processing queue by using the Integrators API. These new messages are submitted by a HTTP POST to API at http://hub.spreecommerce.com, and must contain the following fields:

* `message` - This key represents the message type, in colon notation. For example: `order:new`, `order:updated`, `user:new`, `shipment:ready`
* `payload` - The payload contains all message-specific details. For example, in the case of `order:new` it would contains order details.

Each message type may require specific details within the `payload` field, please review the [Message Library]() for the specific message type requirements.

The API response will include all the details submitted, along with a `message_id` for the newly-created message.

All messages submitted via the API are first passed to the Incoming Queue where they are validated, and once processed they will be submitted to Accepted Queue.

***
The `message_id` returned by the API is message's Incoming Queue message_id, as the message maybe be duplicated several times when it's passed onto the Accepted Queue each new message will have its own _message_id_. Each new Accepted message will maintain a reference to its source Incoming message by storing the original `message_id` in the `parent_id` field.
***

### New Product Example

If your integration was responsible for managing products, it may want to add new products to the Spree store (and other systems) when they have been marked for sale. In this instance you would push a "New Product" message that would create the product within the Spree store and notify any other external systems that were subscribed to that event.

You will need to get your STORE_ID and your authorization token in order to push messages. Once you've connected your store, you can get both of these values by accessing your store's console and running: 

<% ruby do %> 
	AuguryEnvironment.last
<% end %>

Once you have the token and STORE_ID value, substitute the STORE_ID into the URL. The token is included via an HTTP header, X-Augury-Token.

    POST http://hub.spreecommerce.com/api/stores/STORE_ID/messages/

Here's an example curl command you can use for testing, assuming you have the example below saved in "new_product.json"

```bash
curl --data @new_product.json -H "X-Augury-Token:MY-TOKEN" -H "Content-Type:application/json" http://hub.spreecommerce.com/api/stores/STORE_ID/messages```


<pre class="headers"><code>Sample: New Product Push</code></pre>
<%= json :new_product_push %>

response will be:

<pre class="headers"><code>Sample: New Product Response</code></pre>
<%= json :new_product_push_response %>

Spree Professional will then route this message to the Spree store for processing, and any other consumers that are registered for that event.

