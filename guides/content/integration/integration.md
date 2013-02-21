
## Sample New Order event work flow

In this example, a customer has just completed a checkout on a store which results in a "New Order" event has being created.

The integrator has already configured an endpoint for "New Order" events, so the following JSON is POST'ed to that URL.

<pre class="headers"><code>Sample: New Order Message</code></pre>
<%= json :new_order_event %>

As you can see the message includes all the details relating to the order.

The endpoint can then carry out any work needed, and must respond to the POST request with a JSON response to indicate that the message has been processed.

<pre class="headers"><code>Sample: New Order Response</code></pre>
<%= json :new_order_response %>

Optionally, the endpoint can include "event" details what will be displayed alongside the order within the Spree administration interface.
