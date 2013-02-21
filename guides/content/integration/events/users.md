---
title: Spree Professional > User Events
---

# User Events

This guide explains the two events that maybe consumed relating to users:

* TOC
{:toc}

## New User Event

In this example, a user has just signed up on a store which results in a "New User" event has being created.

The integrator has already configured an endpoint for "New User" events, so the following JSON is POST'ed to that URL.

<pre class="headers"><code>Sample: New User Message</code></pre>
<%= json :new_user_event %>

As you can see the message includes all the details relating to the user.

The endpoint can then carry out any work needed, and must respond to the POST request with a JSON response to indicate that the message has been processed.

<pre class="headers"><code>Sample: New User Response</code></pre>
<%= json :new_user_response %>

Optionally, the endpoint can include "event" details what will be displayed alongside the user within the Spree administration interface.


## Updated User Event

After the initial "New User" event, any changes should result in an "Updated User" event. 

The integrator has already configured an endpoint for "Updated User" events, so the following JSON is PUT'ed to that URL.

<pre class="headers"><code>Sample: Updated User Message</code></pre>
<%= json :updated_user_event %>

As you can see the message includes all the details relating to the updated user.

The endpoint can then carry out any work needed, and must respond to the PUT request with a JSON response to indicate that the message has been processed.

<pre class="headers"><code>Sample: Updated User Response</code></pre>
<%= json :updated_user_response %>

Optionally, the endpoint can include "event" details what will be displayed alongside the user within the Spree administration interface.