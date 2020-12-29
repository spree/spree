---
title: Users
description: Use the Spree Commerce storefront API to access User data.
---

List users visible to the authenticated user. If the user is not an admin,
they will only be able to see their own user, unless they have custom
permissions to see other users. If the user is an admin then they can see all
users.

```text
GET /api/v1/users
```

Users are paginated and can be iterated through by passing along a `page`
parameter:

```text
GET /api/v1/users?page=2
```

### Response

<status code="200"></status>
<json sample="users"></json>

## A single user

To view the details for a single user, make a request using that user\'s
id:

```text
GET /api/v1/users/1
```

### Successful Response

<status code="200"></status>
<json sample="user"></json>

### Not Found Response

<alert type="not_found"></alert>

## Pre-creation of a user

You can learn about the potential attributes (required and non-required) for a
user by making this request:

```text
GET /api/v1/users/new
```

### Response

<status code="200"></status>
```json
{
  "attributes": ["<attribute1>", "<attribute2>"],
  "required_attributes": []
}
```

## Creating a new new

<alert type="admin_only" kind="danger"></alert>

To create a new user through the API, make this request with the necessary
parameters:

```text
POST /api/v1/users
```

For instance, a request to create a new user with the email
\"spree@example.com\" and password \"password\" would look like this:

```text
POST /api/v1/users?user[email]=spree@example.com&user[password]=password
```

### Successful response

<status code="201"></status>

### Failed response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {
    "email": ["can't be blank"]
  }
}
```

## Updating a user

<alert type="admin_only" kind="danger"></alert>

To update a user\'s details, make this request with the necessary parameters:

```text
PUT /api/v1/users/1
```

For instance, to update a user\'s password, send it through like this:

```text
PUT /api/v1/users/1?user[password]=password
```

### Successful response

<status code="201"></status>

### Failed response

<status code="422"></status>
```json
{
  "error": "Invalid resource. Please fix errors and try again.",
  "errors": {
    "email": ["can't be blank"]
  }
}
```

## Deleting a user

<alert type="admin_only" kind="danger"></alert>

To delete a user, make this request:

```text
DELETE /api/v1/users/1
```

### Response

<status code="204"></status>

