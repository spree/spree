---
title: Consuming Messages
---

## Consuming Messages

When an endpoint is registered to consume messages, it will receive a JSON-encoded HTTP POST to the configured endpoint URL.

Each message will contain at least the following fields:

* `message` - This key represents the message type, in colon notation. For example: `order:new`, `order:updated`, `user:new`, `shipment:ready`
* `message_id` - A unique id (BSON::ObjectId) for the message.
* `payload` - The payload contains all message specific details. For example, in the case of `order:new` it would contains order details.

<pre class="headers"><code>Basic message fields</code></pre>
<%= json :message %>

The Integrator is responsible for ensuring each event is received and processed successfully by each subscribed endpoint.


## Responding to messages

Each endpoint must return a valid json (content-type='application/json') response, including a HTTP 200 response code to confirm the message has been successfully processed.

An endpoint can choose to make two standard responses:

### Synchronous Response

A synchronous response indicates that the message has been completed / processed within the normal HTTP request / response cycle. Most endpoints perform synchronously as the Integrator is configured to wait up to 180 seconds for a response from an endpoint. This is generally sufficient for processing most messages.

The synchronous response must contain at minimum the `message_id` of the message that was processed, and may additionally contain any / all of the following optional fields:

* `messages` - An array of new messages that should be accepted onto the internal queue of the Integrator as a result of the message being processed. For example, the Mandrill endpoint consumes the `new:order` message and generates an `order:confirmation:sent` message as a result. For details on the specific fields required please review <%= link_to "Pushing Messages",'push' %>.
* `events` - An array of new events which should be logged as a result of the message being processed.

<pre class="headers"><code>Synchronous Response</code></pre>
<%= json :sync_message_response %>

A synchronous response may also include any additional attributes with the JSON response, which will be persisted for logging and diagnostic purposes.

### Asynchronous Response

An asynchronous (or delayed) response indicates that the message requires a longer period of time for processing (than the default 180 second endpoint response window) or may be dependent on a scheduled event to be considered fully processed.

An asynchronous (or delayed) response indicates that the message either requires longer than 180 seconds to process or may be dependent on completion of a scheduled event. 

An asynchronous response must contain _only_ the following fields:

* `message_id` - The id of the current message that has been submitted for processing.
* `delay` - An integer indicating the minimum number of seconds before attempting to poll the update_url.
* `update_url` - The URL that the integrator should poll to check for message completion.

<pre class="headers"><code>Asynchronous Response</code></pre>
<%= json :async_message_response %>

On receipt of an asynchronous response, the Integrator will wait the allotted delay period and begin polling the `update_url` for a completion response.

Each poll to the `update_url` will be a HTTP POST containing the original message:

<pre class="headers"><code>Update Request</code></pre>
TODO: Update request
<%= json :update_request %>

The endpoint can then choose to respond to this update message with either the standard:

* _Asynchronous Response_ - if the message _has not_ yet been completed successfully.
* _Synchronous Response_ - if the message _has_ been completed successfully.

## Failures

If at any stage an endpoint returns any HTTP response code other than 200, regardless of the response body, the message will be deemed as failed and will be retried using an exponential back-off algorithm.
