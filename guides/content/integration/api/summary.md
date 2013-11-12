---
title: Summary
---

## Overview

The Spree Commerce hub currently supports RESTful access to the resources listed under the "API"
section in the sidebar to the right.

This API was built using the great [Jbuilder](https://github.com/rails/jbuilder) gem.
Please consult its documentation if you wish to understand how the templates use
it to return data.

This API conforms to a set of [rules](#rules).

### JSON Data

Developers communicate with the Spree Commerce hub API using the [JSON](http://www.json.org) data format. Requests for data are communicated in the standard manner using the HTTP protocol.

### Making an API Call

***
To find your hub API token and Store ID, navigate to /admin/integration/connection within your
hub connected store.
***

You will need an authentication token to access the API. These keys can be generated on the user edit screen within the admin interface. To make a request to the API, pass a `X-Augury-Token` header along with the request:

```bash
$ curl --header "X-Augury-Token: YOUR_KEY_HERE" http://hub.spreecommerce.com/api/stores/YOUR_STORE_ID/integrations.json```

The token allows the request to assume the same level of permissions as the actual user to whom the token belongs.

### Error Messages

You may encounter the follow error messages when using the API.

#### Invalid Resource

<%= invalid_resource %>

#### Invalid Token

<%= invalid_token %>

#### Store Not Found

<%= store_not_found %>

## Rules

The following are some simple rules that all Spree Commerce hub API endpoints comply with.

1. All successful requests for the API will return a status of 200.
2. Successful create and update requests will result in a status of 201 and 200 respectively.
3. Both create and update requests will return a JSON representation of the data upon success.
4. If a create or update request fails, a status code of 422 will be returned, with a hash containing an \"error\" key, and an \"errors\" key. The errors value will contain all ActiveRecord validation errors encountered when saving this record.
5. Delete requests will return status of 200, and no content.
6. If a resource can not be found, the API will return a status of 404.
7. Unauthorized requests will be met with a 401 response.
