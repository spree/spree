Public Views
============

Layout (layouts/spree_application.html.erb)
------------------------------------------------
* head (allows you to add content at the bottom of the head tag)
* sidebar_bottom (at the bottom of any page that has a sidebar)

Homepage (products/index.html.erb)
----------------------------------

* homepage_sidebar_below_navigation
* homepage_above_products
* homepage_below_products

Taxon (taxons/show.html.erb)
----------------------------

* taxon_sidebar_below_navigation
* taxon_above_products
* taxon_below_products
* taxon_above_children
* taxon_below_children

View Product (products/show.html.erb products/_taxons.html.erb products/_cart_form.html.erb)
--------------------------------------------------------------------------------------------

* product_below_description
* product_below_properties
* product_below_taxons (below 'Look for similar items')
* product_above_price
* product_below_price
* product_below_cart_form

Cart (orders/edit.html.erb)
---------------------------

* cart_top (just below the page title)
* cart_above_items (above the table of line items, within the form)
* cart_below_items
* cart_bottom (bottom of the cart page)

Checkout (checkouts/edit.html.erb)
----------------------------------

* checkout_singlepage_top (just below page title)
* checkout_singlepage_bottom (after the cart form)

Login (user_sessions/new.html.erb)
----------------------------------

* login_top
* login_bottom

Signup (users/new.html.erb, users/_form.html.erb)
---------------------------

* signup_top
* signup_bottom
* signup_above_email_field (within form, above email field)
* signup_below_password_fields (within form, below password confirmation field)

Account (users/show.html.erb)
-----------------------------

* account_top
* account_above_my_orders
* account_below_my_orders

Admin Views
===========

Layout (layouts/admin.html.erb)
-------------------------------

* admin_head (allow scripts etc. to be added to the head tab)

Navigation
----------

The following hooks allow list items to be added to various admin menus

* admin_tabs
* admin_product_sub_tabs
* admin_order_tabs (sidebar menu for individual order)
* admin_product_tabs (sidebar menu for individual product)

