---
title: Pushing Messages
---

## Pushing Messages

External systems can push messages on to the Integrators processing queue by using the Integrators API. These new messages are submmited by a HTTP POST to API at http://integrator.spreecommerce.com, and must contain the following fields:

* _message_ - This key represents the message type, in colon notation for example: _order:new_, _order:updated_, _user:new_, _shipment:ready_
* _store_id_ - This is the store identifier (BSON::ObjectId).
* _payload_ - The payload contains all message specific details, for example in the case of _order:new_ it would contains orders details.

Each message type may require specific details within the _payload_ field, please review the [Sample Messages](/integration/samples/) for the specific message type requirments.

The API response will include all the details submitted, along with a _message_id_ for the newly created message.

All messages submitted via the API are first passed to the Incoming Queue where they are validated, and once processed they will be submitted to Accepted Queue. The _message_id_ returned by the API is message's Incoming Queue message_id, as the message maybe be duplicated several times when it's passed onto the Accepted Queue each new message with have its own _message_id_. Each new Accepted message will maintain a reference to its source Incoming message by storing the original _message_id_ in the _parent_id_ field.



### New Product Example

If your integration was responsible for managing products, it may want to add new products to the Spree store (and other systems) when they have been marked for sale. In this instance you would push a "New Product" message that would create the product within the Spree store and notify any other external systems that were subscribed to that event.

    POST http://integrator.spreecommerce.com/messages

<pre class="headers"><code>Sample: New Product Push</code></pre>
<%= json :new_product_push %>

response will be:

<pre class="headers"><code>Sample: New Product Response</code></pre>
<%= json :new_product_push_response %>

Spree Professional when then route this message to the Spree store for processing, and any other consumers that are registered for that event.

