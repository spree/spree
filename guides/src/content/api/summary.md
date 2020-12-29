---
title: Summary
order: 0
---

## Overview

Spree currently supports RESTful access to the resources listed in the sidebar
on the right &raquo;

This API was built using the great [Rabl](https://github.com/nesquena/rabl) gem.
Please consult its documentation if you wish to understand how the templates use
it to return data.

This API conforms to a set of [rules](#rules).

### JSON Data

Developers communicate with the Spree API using the [JSON](http://www.json.org) data format. Requests for data are communicated in the standard manner using the HTTP protocol.

### Making an API Call

You will need an authentication token to access the API. These keys can be generated on the user edit screen within the admin interface. To make a request to the API, pass a `X-Spree-Token` header along with the request:

```bash
$ curl --header "X-Spree-Token: YOUR_KEY_HERE" http://example.com/api/v1/products.json
```


Alternatively, you may also pass through the token as a parameter in the request if a header just won't suit your purposes (i.e. JavaScript console debugging).

```bash
$ curl http://example.com/api/v1/products.json?token=YOUR_KEY_HERE
```

The token allows the request to assume the same level of permissions as the actual user to whom the token belongs.

### Error Messages

You may encounter the follow error messages when using the API.

#### Not Found

<alert type="not_found"></alert>

#### Authorization Failure

<alert type="authorization_failure"></alert>

#### Invalid API Key

<status code="401"></status>
```json
{ "error": "Invalid API key ([key]) specified." }
```

#### No API Key specified

<alert type="no_api_key"></alert>

## Rules

The following are some simple rules that all Spree API endpoints comply with.

1. All successful requests for the API will return a status of 200.
2. Successful create and update requests will result in a status of 201 and 200 respectively.
3. Both create and update requests will return Spree\'s representation of the data upon success.
4. If a create or update request fails, a status code of 422 will be returned, with a hash containing an \"error\" key, and an \"errors\" key. The errors value will contain all ActiveRecord validation errors encountered when saving this record.
5. Delete requests will return status of 200, and no content.
6. Requests that list collections, such as `/api/v1/products` are paginated and
   will return 25 records per page. You can speficy your own `per_page` value.
7. Requests that list collections can be paginated through by passing a `page`
   parameter, `page=1` being the first page.
8. If a resource can not be found, the API will return a status of 404.
9. Unauthorized requests will be met with a 401 response.

## Customizing Responses

If you wish to customize the responses from the API, you can do this in one of
two ways: overriding the template, or providing a custom template.

### Overriding template

Overriding a template for the API should be done if you want to provide a custom
response for an API endpoint. Template loading in Rails will attempt to look up
a template within your application's view paths first. If it isn't available
there, then it will fallback to looking within the other engine's view paths,
eventually finding its way to the API engine.

You can use this to your advantage and define a view template within your
application that exists at the same path as a template within the API engine.
For instance, if you place a template in your application at
`app/views/spree/api/v1/products/show.v1.rabl`, it will take precedence over the
template within the API engine.
