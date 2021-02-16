---
title: API
section: security
order: 3
---

## REST API v1

The REST API behaves slightly differently than a standard user. First, an admin has to create the access key before any user can query the REST API. This includes generating the key for the admin him/herself. This is not the case if `Spree::Api::Config[:requires_authentication]` is set to `false`.

In cases where `Spree::Api::Config[:requires_authentication]` is set to `false`, read-only requests in the API will be possible for all users. For actions that modify data within Spree, a user will need to have an API key and then their user record would need to have permission to perform those actions.

It is up to you to communicate that key. As an added measure, this authentication has to occur on every request made through the REST API as no session or cookies are created or stored for the REST API.
