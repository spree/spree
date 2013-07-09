---
title: Message Basics
---

## Message Generation

The Spree Integrator is responsible for processing and delivering [messages](terminology#messages) based on a pre-configured set of business logic specific to a particular store. The messages processed by the Integrator are generated in one of three possible ways.

### Polling

The most common way for messages to enter the system is via a scheduled poller that talks to the Spree API. These pollers will ask Spree for new messages since the last time it checked and for changes to messages that it has already polled (but that have changed since we last checked.)

It's not important to understand exactly how these API differences result in a message. For the purposes of this guide it is sufficient for you to understand that changes to Orders, Payments, Shipments, etc. come in via a scheduled polling action at regular intervals. The result of this will be a series of appropriate messages relevant to the state change.

For example, if the API poller comes back with an order that the Integrator is not already aware of, then this results in an `order:new` message. If the order already existed but the API poller was showing some kind of change (ex. a change in quantity for a line item) then an `order:update` message would be generated instead.

Finally, in some instances, an update to an order can result in a more specific message being generated. For instance, if the order status was changed from `complete` to `canceled` an `order:cancel` message would be produced instead of the more general `order:update`.

***
See the specific [Message](messages_overview) guides for more details on each of these and other message types.
***

### Response

The second way for a message to enter the system is in response to a [service request](terminology#service_requests) to an [endpoint](terminology#endpoints). When an endpoint is processing a message it will typically respond with a new message. That new message can in turn be processed by the integrator.

Let's look at a specific example where we are using an integration that takes new shipments and dispatches them to a third party logistics provider (3PL) for drop shipping. The `process_shipment` service of this endpoint will return a `notification:info` message in response to this service request.

```ruby
post '/process_shipment' do
  # DO STUFF HERE
  process_result 200, { 'message_id' => @message[:message_id],
                        'message' => 'notification:info',
                        'payload' => {
                          'subject' => 'Shipment transmitted',
                          'description' => '#H123456 transmitted successfully.'
                        }
                      }
end```

In the above example, we returned a single message in the response but messages generated in this way are technically an array of messages and so it is possible to generate more than one message as part of a service request. For example, if you were designing a service that returned the list of shipments that have shipped since the last check, then you would likely need to return multiple `shipment:confirm` messages.

***
See the [Creating Endpoints](creating_endpoints_tutorial) tutorial for some more detailed examples on how to generate messages in response to processing a service request.
***

### Push

Finally, it is possible to push messages into the Integrator from an external source.

$$$
Need more docs on message push.
$$$

***
Endpoints should never push messages since they are intended to be a passive consumer of messages. Instead, they should be polled via a message sent from the Integrator so they can return the necessary information.
***

## Service Requests

## Message Delivery

### Successful Delivery

### Failed Delivery

### Error on Delivery

## Message Parameters