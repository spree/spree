---
title: Orders
---

## List all orders

<%= admin_only %>

Retrieve a list of orders by making this request:

```text
GET /api/orders```

Orders are paginated and can be iterated through by passing along a `page` parameter:

```text
GET /api/orders?page=2```

### Parameters

page
: The page number of order to display.

per_page
: The number of orders to return per page

### Response

<%= headers 200 %>
<%= json(:order) do |h|
{ :orders => [h],
  :count => 25,
  :pages => 5,
  :current_page => 1 }
end %>

## Order searching

To search for a particular order, make a request like this:

```text
GET /api/orders?q[email_cont]=bob```

The searching API is provided through the Ransack gem which Spree depends on. The `email_cont` here is called a predicate, and you can learn more about them by reading about [Predicates on the Ransack wiki](https://github.com/ernie/ransack/wiki/Basic-Searching).

The search results are paginated.

### Response

<%= headers 200 %>
<%= json(:order) do |h|
 { :orders => [h],
   :count => 25,
   :pages => 5,
   :current_page => 1 }
end %>

### Sorting results

Results can be returned in a specific order by specifying which field to sort by when making a request.

```text
GET /api/orders?q[s]=number%20desc```

It is also possible to sort results using an associated object's field.

```text
GET /api/orders?q[s]=user_name%20asc```

## A single order

To view the details for a single product, make a request using that order\'s number:

```text
GET /api/orders/R123456789```

Orders through the API will only be visible to admins and the users who own them. If a user attempts to access an order that does not belong to them, they will be met with an authorization error.

### Successful Response

<%= headers 200 %>
<%= json :order_show %>

### Not Found Response

<%= not_found %>

### Authorization Failure

<%= authorization_failure %>

## Creating a new order

To create a new order through the API, make this request:

```text
POST /api/orders```

If you wish to create an order with a line item matching to a variant whose ID is \"1\" and quantity is 5, make this request:

```text
POST /api/orders?order[line_items][0][variant_id]=1&order[line_items][0][quantity]=5```

### Successful response

<%= headers 201 %>

### Failed response

<%= headers 422 %>
<%= json \
  :error => "Invalid resource. Please fix errors and try again.",
  :errors => {
    :name => ["can't be blank"],
    :price => ["can't be blank"]
  }
%>

## Modifying address information

To add address information to an order, make this request with the correct parameters:

```text
PUT /api/orders/:number/address```

You may choose to pass through both the shipping address or billing address.

With an order number of R1234567, updating an address would be done like this:

```text
PUT /api/orders/:number/address?shipping_address[firstname]...```

The valid address parameters are:

* firstname
* lastname
* company
* address1
* address2
* city
* zipcode
* phone
* alternative_phone
* country_id
* state_id

Once valid address information has been submitted, the shipping methods available for this order will be returned inside a `shipping_methods` key inside the order:

<%= json(:shipping_method) do |h|
 { :order => { :shipping_methods => [h] } }
end %>

## Selecting a delivery method

To choose a delivery method for the order, pass along one ID from the `shipping_methods` response that you would receive from making a request to update the order\'s address, or by making another request to `GET /api/orders/R1234567` while the order is in the \"delivery\" state.

Make a request like this to select the delivery method:

```text
PUT /api/orders/R1234567?shipping_method_id=1```

Upon a successful request, the order will transition to the `payment` state.

## Emptying an Order

To empty an order\'s cart, make this request:

```text
PUT /api/orders/R1234567/empty```

All line items will be removed from the cart and the order\'s information will
be cleared. Inventory that was previously depleted by this order will be
repleted.
