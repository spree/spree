---
title: Summary
---

# Summary

Spree currently supports RESTful access to the resources listed in the sidebar
on the right &raquo;

This API was built using the great [Rabl](https://github.com/nesquena/rabl) gem.
Please consult its documentation if you wish to understand how the templates use
it to return data.

This API conforms to a set of [rules](/rules).

## JSON Data

Developers communicate with the Spree API using the [JSON](http://www.json.org) data format. Requests for data are communicated in the standard manner using the HTTP protocol.

## Making an API Call

You will need an authentication token to access the API. These keys can be generated on the user edit screen within the admin interface. To make a request to the API, pass a `X-Spree-Token` header along with the request:

    curl --header "X-Spree-Token: YOUR_KEY_HERE" http://example.com/api/products.json


Alternatively, you may also pass through the token as a parameter in the request if a header just won’t suit your purposes (i.e. JavaScript console debugging).

    curl http://example.com/api/products.json?token=YOUR_KEY_HERE

The token allows the request to assume the same level of permissions as the actual user to whom the token belongs.

## Error Messages

You may encounter the follow error messages when using the API.

### Not Found

<%= not_found %>

### Authorization Failure

<%= authorization_failure %>

### Invalid API Key

<%= headers 401 %>
<%= json(:error => "Invalid API key ([key]) specified.") %>
