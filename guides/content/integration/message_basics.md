---
title: Message Basics
---

## Message Generation

The Spree Integrator is responsible for processing and delivering [Messages](terminology#messages) based on a pre-configured set of business logic specific to a particular store. The Messages processed by the Integrator are generated in one of three possible ways.

### Polling

The most common way for Messages to enter the system is via a scheduled Poller that talks to the Spree API. These Pollers will ask Spree for new Messages that have been created or updated since the last time it checked.

It's not important to understand exactly how these API differences result in a Message. For the purposes of this guide, it is sufficient for you to understand that changes to Orders, Payments, Shipments, etc. come in via a scheduled polling action at regular intervals. The result of this will be a series of appropriate Messages relevant to the state change.

For example, if the API Poller comes back with an order that the Integrator is not already aware of, then this results in an `order:new` Message. If the order already existed but the API Poller was showing some kind of change (ex. a change in quantity for a line item) then an `order:update` Message would be generated instead.

Finally, in some instances, an update to an order can result in a more specific Message being generated. For instance, if the order status was changed from `complete` to `canceled` an `order:cancel` Message would be produced instead of the more general `order:update`.

***
See the specific [Message](messages_overview) guides for more details on each of these and other Message Types.
***

### Response

The second way for a Message to enter the system is in response to a [Service Request](terminology#service_requests) to an [Endpoint](terminology#endpoints). When an Endpoint is processing a Message, it will typically respond with a new Message. That new Message can in turn be processed by the Integrator.

Let's look at a specific example where we are using an integration that takes new shipments and dispatches them to a third party logistics provider (3PL) for drop shipping. The `process_shipment` Service of this Endpoint will return a `notification:info` Message in response to this Service Request.

```ruby
post '/process_shipment' do
  # DO STUFF HERE
  process_result 200,
    { 'message_id' => @message[:message_id],
      'messages' => [
        { 'message' => 'notification:info',
          'payload' => {
            'subject' => 'Shipment transmitted',
            'description' => '#H123456 transmitted successfully.'
          }
        }
      ]
    }
end```

In the above example, we returned a single Message in the response, but Messages generated in this way are technically an array of Messages and so it is possible to generate more than one Message as part of a Service Request. For example, if you were designing a Service that returned the list of shipments that have shipped since the last check, then you would likely need to return multiple `shipment:confirm` Messages.

***
See the [Creating Endpoints](creating_endpoints_tutorial) tutorial for some more detailed examples on how to generate Messages in response to processing a Service Request.
***

### Push

Finally, it is possible to push Messages into the Integrator from an external source.

$$$
Need more docs on message push.
$$$

***
Endpoints should never push Messages, since they are intended to be a passive consumer of Messages. Instead, they should be polled via a Message sent from the Integrator, so that they can return the necessary information.
***

## Service Requests

Integration Endpoints expose various [Services](terminology#services) to the Integrator. The Integrator is configured with a series of [Mappings](terminology#mappings), which tell it how it route a specific Message to a particular Service offered by an Endpoint.

***
See the [Mapping Guide](mapping_basics) for more information on how Messages are mapped to Endpoints.
***

Passing a Message to a particular Endpoint Service is also referred to as making a [Service Request](terminology#service_request). Service Requests are always made use the `HTTP POST` method and the Messages they pass are required to be in a JSON format. Now let's take a look at some aspects of message delivery.

***
Integrations can be written in any language (not just Ruby). All that is required is that your Endpoint be able to respond to `HTTP POST` requests, and that your Service methods be capable of reading a JSON-formatted form parameter.
***

## Message Delivery

Messages routed through the Integrator are guaranteed to be delivered to their intended Endpoints. When attempting to deliver a Message to a Service (i.e. making a Service Request), one of three things can happen.

### Successful Delivery

If the Message is delivered to the Endpoint and it is processed without incident, then the Message can be considered successfully delivered. The minimum requirement for an Endpoint to indicate that the Service Request was successful is to return a `200 OK` response, along with the `message_id`.

The following is a simple example of an Endpoint built using Sinatra to return the bare minimum required to indicate successful processing of the Message.

```ruby
post '/do_something' do
  message = JSON.parse(request.body.read)
  json 'message_id' => message['message_id']
end```

Here's what the server sends back when a Message is sent to the `do_something` service via `HTTP POST`:

```bash
HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 35
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Tue, 02 Jul 2013 20:12:23 GMT
Connection: Keep-Alive

{"message_id":"518726r84910000001"}```

***
See the [Creating Endpoints](creating_endpoints_tutorial) tutorial for more detailed examples of how to build simple Endpoints.
***

There is, however, a more informative way to convey the successful delivery of a Message. In addition to returning `200 OK` a Service can return an array of Messages (or just a single Message). The previous discussion of [Responses](#response) contains an example of how this can be done.

Responding with a [Notification Message](notification_messages) has the advantage of allowing the Service to pass additional human-readable information back to the Integrator. By default, Notification Messages will be turned into [Log Entries](terminology#log_entries), which can be displayed in a detailed tab in the store's admin interface.

Sometimes, however, it's important to convey more than just "success" plus a log entry. A major advantage to using Spree Integrator is that it allows one integration to respond to events taking place in another. In order for this to happen, however, the Service Request of the first integration needs to return something more specific in addition to a log message.

Let's look at a specific example where we want a particular integration to capture a previously authorized credit card payment once a shipment is ready to ship. Suppose further that we want to send an email message to the customer once we capture the payment on their card. Once we've taken care of the necessary Mappings, we could use an Endpoint with a `capture_payment` method.

---payment_integration.rb---
```ruby
post '/capture_payment' do
  # DO STUFF HERE
  process_result 200,
    { 'message_id' => @message[:message_id],
      'messages' => [
        { 'message' => 'notification:info',
          'payload' => {
            'subject' => 'Payment captured',
            'description' => 'Captured: 00000111122223333'
          }
        },
        { 'message' => 'payment:capture',
          'payload' => {
            'payment' => {
              'payment_id' => '12345567890',
              'amount' => '19.99',
              'currency' => 'USD'
            },
            'auth_code' => '00000111122223333',
            'timestamp' => '1969-07-21 T 02:56 UTC'
          }
        }
      ]
    }
end```

In this case we've actually returned multiple Messages. We return a `notification:info` Message so that can be displayed on the events tab in the Spree store, but we also return a `payment:capture` Message. The idea here is that another integration can then listen specifically for `payment:capture` Messages and do something specific knowing that a payment has been captured (update Quickbooks, send an email to the customer, etc.)

***
Note that Services are not required to return a pre-defined Message Type. You are free to create your own Endpoints that return custom Message Types.
***

### Error on Delivery

There are various error conditions that may be encountered during the processing of a Service Request. Endpoints can have logic that maps to either internal business rules or the rules/validation logic of a third party API that it's facilitating integration with.

Let's look at a specific example. Suppose you are working with a third party logistics (3PL) firm to drop ship your packages to your customers. Suppose further that this 3PL has an API that checks to verify that it can deliver to the requested address before it accepts your ship instructions. When this happens, you will most likely want to return a [Notification Error](notification_messages#error) Message.

The `notification:error` Message is used to signify that there was a problem with processing that Service Request. This approach should be used when the nature of the problem is that the request is not consistent with some type of business logic, or the rules of the third party API that you're communicating with are not met.

---validation_failure_example.rb---
```ruby
post '/ship_package' do
  # AFTER 3PL TELLS US CAN'T DELIVER
  process_result 200,
    { 'message_id' => @message[:message_id],
      'messages' => [
        { 'message' => 'notification:error',
          'payload' => {
            'subject' => 'Can't deliver to that address',
            'description' => 'Afghanistan is not somewhere we ship to!'
          }
        }
      ]
    }
end```

***
Use a Notification Error when the problem is a "validation" type issue or some other problem with a third party API where it does not make sense to reattempt the Service Request.
***

!!!
Error conditions should always be returned with status code `HTTP OK` even though there was technically a problem. They are distinct from [Failures](terminology#failures) which are returned with `HTTP 5XX` error codes.
!!!

### Failed Delivery

## Message Parameters
