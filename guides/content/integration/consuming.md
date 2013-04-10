---
title: Consuming Messages
---

## Consuming Messages

When an endpoint is registered to consume messages, it will receive a JSON encoded HTTP POST to the configured endpoint URL.

Each message will contain at least the following fields:

* _message_ - This key represents the message type, in colon notation for example: _order:new_, _order:updated_, _user:new_, _shipment:ready_
* _message_id_ - A unique id (BSON::ObjectId) for the message.
* _payload_ - The payload contains all message specific details, for example in the case of _order:new_ it would contains orders details.

<pre class="headers"><code>Basic message fields</code></pre>
<%= json :message %>

The Integrator is responsible for ensuring each event is received and processed successfully by each subscribed endpoint.


## Responding to messages

Each endpoint must return a valid json (content-type='application/json') response, including a HTTP 200 response code to confirm the message has been successfully processed.

An endpoint can chose to make two standard responses:

### Synchronous Response

A synchronous response indicates that the message has been completed / processed within the normal HTTP request / response cycle. Most endpoints perform synchronously as the Integrator is configured to wait for upto 180 seconds for a response from an endpoint which is generally sufficient for processing most messages.

The synchronous response must contain at minimum the _message_id_ of the message that was processed, and may contain any / all of the following optional fields:

* _messages_ - An array of new messages that should be accepted onto the internal queue of the Integrator as a result of the message being processed, for example the Mandrill endpoint consumes the _new:order_ message and generates an _order:confirmation:sent_ message as a result. For details on the specific fields required please review <%= link_to "Pushing Messages",'push' %>.
* _events_ - An array of new events which should be logged as a result of the message being processed.

<pre class="headers"><code>Synchronous Response</code></pre>
<%= json :sync_message_response %>

A synchronous response may also include any additional attributes with the JSON response, which will be persisted for logging and diagnostic purposes.

### Asynchronous Response

An asynchronous (or delayed) response indicates that the message requires a longer period of time for processing (than the default 180 second endpoint response window) or may be dependant on a scheduled event to be considered fully processed.

An asynchronous response must ONLY contain the following fields:

* _message_id_ - The id of the current message that has been submitted for processing.
* _delay_ - An integer indicating the minimum number of seconds before attempting to poll the update_url.
* _update_url_ - The URL that the integrator should poll to check for message completion.

<pre class="headers"><code>Asynchronous Response</code></pre>
<%= json :async_message_response %>

On receipt of an asynchronous response, the Integrator will wait the alloted delay period and begin polling the _update_url_ for a completion response.

Each poll to the _update_url_ will be a HTTP POST containing just the _message_id_:

<pre class="headers"><code>Update Request</code></pre>
<%= json :update_request %>

The endpoint can then choose to respond to this update message with either the standard:

* _asynchronous response_ - if the message has NOT yet been completed successfully.
* _synchronous response_ - if the message HAS been completed successfully.

## Failures

If at any stage an endpoint returns any HTTP response code other than 200, regardless of the response body, the message will be deemed as failed and will be retried using an exponential back-off algorithm.
