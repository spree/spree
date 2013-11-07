---
title: Custom Integrations
---

## Overview

Customization is one of the key features of Spree Commerce, every merchant has their own unique requirements and being able to build out custom functionality in both your storefront and within the hub is critical.

The hub allows you to use its powerful messaging and routing features to connect your own custom endpoints, allowing you to integrate in-house systems into your existing workflows.

We've created several [Tutorials](/integration/basic_endpoints_tutorial.html) that walk you through creating a number of different endpoints.

Once you've created your endpoint the next step is to document the services available on the endpoint, and any configuration required to use those services. This configuration detail is contained in a `endpoint.json` file which must be available at the root path of your application.

The hub uses the details within this file to advertise the integration to the Spree Hub Connector, which allows you to configure and enable the services provided.


## Endpoint.json

When configuring an Integration using the Spree Hub Connector the information from the `endpoint.json` is used to populate a [mapping](/integration/mapping_basics.html) with default configuration for each configured service.

The file contains some basic details about your endpoint and lists all the available services including which messages you recommend the service process and all configuration details (like parameters, filters, identifiers that the service may require).

The `endpoint.json` file must be available at the root path of your application via `HTTP GET` request i.e. /endpoint.json

---Endpoint.json summary---
```json
{
    "name": "mandrill",
    "display": "Mandrill",
    "description": "Sends transactional emails using Mandrill",
    "icon_url": "mandrill.png",
    "help": "http://guides.spreecommerce.com/integration/endpoints/mandrill",
    "services": [] 
}```

In the example above we see the general details from the Mandrill `endpoint.json` file, the required entries include:

1. **name** - Name is the title of an endpoint and must be unique, may only contain lowercase letters, and - or _. No whitespace, numbers, or special characters allowed. The name attribute is used in several places for referencing the endpoint; think of it as a permalink.
2. **display** - This is the human name for the endpoint, presented when displaying details relating to the endpoint.
3. **description** - A short text description of the endpoint and the integration it provides.
4. **icon_url** - Is a relative path to an icon file, displayed with listing details relating to the endpoint. Should not exceed 130x130 pixels.
5. **help** - URL of documentation for an endpoint.
6. **services** - Is an array of entries for each available service on the endpoint.


### Service Entries

The majority of the details within an `endpoint.json` file are related to a service entry. The service entries outline all the details required for the hub to interact with your endpoints action:

1. **name** - Following the same formatting rules an the overall endpoint name, each service requires a unique name (within the current endpoint).
2. **path** - The relative path for the service, a message destined for a service will be POST'd to its endpoint's base url + the service path. i.e /order_confirmation
3. **description** - A short text description of the service.
4. **requires** - Identifies any required configuration for a given service (currently only supports listing parameters) unless **optional** flag is provided and set to **true**.
    1. **parameters** - Any parameters required for the given service to process a message. Each parameter has the following attributes:
        1. **name** - Following the same formatting rules as the overall endpoint name, each parameter requires a unique name (within the current endpoint). Note: When parameters are POST'd to a endpoint service along with a message, their names will be prepended with the endpoints name, i.e. "mandrill.api_key".
        2. **description** - A short description of the parameter
        3. **data_type** - Parameters can be "string", "boolean", "integer", "float" or "list".
        4. **default** - A default string value that will be used.
        5. **allowed** - An array of allowed string values or a regular expression string that the parameter will be validated against.
        6. **optional** - A boolean indicating if the parameter will be optional (defaults to false).
5. **recommends** - Additional configuration that the mapping should use as defaults.
    1. **messages** - an array of message types the service would like to process.
    2. **identifiers** - a hash listing values which should be used to prevent duplicate messages from being processed. The key is an arbitrary name, and value is a path to value(s) within the message.
    3. **filters** - an array of filters which the message must pass before being sent to the endpoint.
        1. **path** - the path to value(s) within the message you would like to compare.
        2. **operator** - the comparison operator to use.
        3. **value** - the value to use in the comparison (optional).
    4. **options** - any other recommended options.
        1. **retries_allowed** - a boolean indicating if a message may be automatically retried on failure (defaults to true).


---Example 'services' entry---
```json
{
    "name": "order_confirmation",
    "path": "/order_confirmation",
    "description": "Send order confirmation emails when new orders are placed.",
    "requires": {
        "parameters": [
            {
                "name": "api_key",
                "description": "Mandrill API key",
                "data_type": "string"
            },
            {
                "name": "order_confirmation.from",
                "description": "Reply-to address for email",
                "data_type": "string",
                "allowed": "^[a-zA-Z0-9]+@{1}[a-zA-Z0-9]+"
            },
            {
                "name": "order_confirmation.subject",
                "description": "Subject of email",
                "data_type": "string",
                "default": "Thank you for placing an order!"
            },
            {
                "name": "order_confirmation.template",
                "description": "Mandrill template name",
                "data_type": "string",
                "allowed": [
                    "One", "Two", "Three"
                ]
            }
        ]
    },
    "recommends": {
        "messages": [
            "order:new",
            "order:update"
        ],
        "identifiers": {
            "order_number": "payload.order.number"
        },
        "filters": [
            {
                "path": "payload.order.status",
                "operator": "eq",
                "value": "complete"
            }
        ],
        "options": {
            "retries_allowed": true
        }
    }
}```


