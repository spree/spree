---
title: Users
description: Use the Spree Commerce storefront API to access User data.
---

List users visible to the authenticated user. If the user is not an admin,
they will only be able to see their own user, unless they have custom
permissions to see other users. If the user is an admin then they can see all
users.

```text
GET /api/users```

Users are paginated and can be iterated through by passing along a `page`
parameter:

```text
GET /api/users?page=2```

### Response

<%= headers 200 %>
<%= json(:user) do |h|
    { :users => [h], :count => 25, :pages => 5, :current_page => 1 }
end %>

## A single user

To view the details for a single user, make a request using that user\'s
id:

```text
GET /api/users/1```

### Successful Response

<%= headers 200 %> <%= json :user %>

### Not Found Response

<%= not_found %>

## Pre-creation of a user

You can learn about the potential attributes (required and non-required) for a
user by making this request:

```text GET /api/users/new```

### Response

<%= headers 200 %>
<%= json :attributes => ["<attribute1>", "<attribute2>"], :required_attributes => [] %>

## Creating a new new

<%= admin_only %>

To create a new user through the API, make this request with the necessary
parameters:

```text
POST /api/users```

For instance, a request to create a new user with the email
\"spree@example.com\" and password \"password\" would look like this:

```text
POST /api/users?user[email]=spree@example.com&user[password]=password```

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json :error => "Invalid resource. Please fix errors and try again.",
         :errors => { :email => ["can't be blank"] } %>

## Updating a user

<%= admin_only %>

To update a user\'s details, make this request with the necessary parameters:

```text
PUT /api/users/1```

For instance, to update a user\'s password, send it through like this:

```text PUT /api/users/1?user[password]=password```

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json :error => "Invalid resource. Please fix errors and try again.",
         :errors => { :email => ["can't be blank"] } %>

## Deleting a user

<%= admin_only %>

To delete a user, make this request:

```text
DELETE /api/users/1```

### Response

<%= headers 204 %>

