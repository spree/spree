---
title: Customizing responses
---

# Customizing responses

If you wish to customize the responses from the API, you can do this in one of
two ways: overriding the template, or providing a custom template.

## Overriding template

Overriding a template for the API should be done if you want to *always* provide
a custom response for an API endpoint. Template loading in Rails will attempt to
look up a template within your application's view paths first. If it isn't
available there, then it will fallback to looking within the other engine's view
paths, eventually finding its way to the API engine.

You can use this to your advantage and define a view template within your
application that exists at the same path as a template within the API engine.
For instance, if you place a template in your application at
`app/views/spree/api/products/show.v1.rabl`, it will take precedence over the
template within the API engine.

This is the method we would recommend to *completely* override an API response.

## Custom template

If you don't want to always override the response for an API controller, you can
customize it in another way by creating an alternative template to use for some
API responses.

To do this, create a template under the view directory of your targetted
resource. For instance, if you wanted to customize a response for one of the
actions within the `ProductsController` of the API, you would place the template
at `app/views/spree/api/products`. The template must be given a unique name that
won't conflict with any other templates; you could call it `small_show` for
instance.

If you were to take this route, the new template file's path would be
`app/views/spree/api/products/small_show.v1.rabl`. The `v1` part of the filename
indicates that its a response for version 1 of the API, and the `rabl` on the
end is the markup language used.

To use this new template for your API response, simply pass the `template`
parameter along with the request:
`http://example.com/api/products/1?template=small_show`. The API component of
Spree will then detect this parameter, find the template, and then use this to
render the response.
