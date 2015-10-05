//= require bootstrap-sprockets
//= require jquery
//= require jquery.cookie
//= require jquery.jstree/jquery.jstree
//= require jquery_ujs
//= require jquery-ui/datepicker
//= require jquery-ui/sortable
//= require jquery-ui/autocomplete
//= require modernizr
//= require underscore-min.js
//= require velocity
//= require spree
//= require spree/backend/spree-select2
//= require spree/backend/address_states
//= require spree/backend/adjustments
//= require spree/backend/admin
//= require spree/backend/calculator
//= require spree/backend/checkouts/edit
//= require spree/backend/gateway
//= require spree/backend/general_settings
//= require spree/backend/handlebar_extensions
//= require spree/backend/line_items
//= require spree/backend/line_items_on_order_edit
//= require spree/backend/nested-attribute
//= require spree/backend/option_type_autocomplete
//= require spree/backend/option_value_picker
//= require spree/backend/orders/edit
//= require spree/backend/orders/edit_form
//= require spree/backend/payments/edit
//= require spree/backend/payments/new
//= require spree/backend/product_picker
//= require spree/backend/progress
//= require spree/backend/promotions
//= require spree/backend/returns/expedited_exchanges_warning
//= require spree/backend/returns/return_item_selection
//= require spree/backend/shipments
//= require spree/backend/states
//= require spree/backend/stock_management
//= require spree/backend/stock_movement
//= require spree/backend/stock_transfer
//= require spree/backend/taxon_autocomplete
//= require spree/backend/taxon_tree_menu
//= require spree/backend/taxonomy
//= require spree/backend/taxons
//= require spree/backend/user_picker
//= require spree/backend/variant_autocomplete
//= require spree/backend/variant_management
//= require spree/backend/zone

Spree.routes.clear_cache = Spree.pathFor('admin/general_settings/clear_cache')
Spree.routes.checkouts_api = Spree.pathFor('api/checkouts')
Spree.routes.classifications_api = Spree.pathFor('api/classifications')
Spree.routes.option_type_search = Spree.pathFor('api/option_types')
Spree.routes.option_value_search = Spree.pathFor('api/option_values')
Spree.routes.orders_api = Spree.pathFor('api/orders')
Spree.routes.products_api = Spree.pathFor('api/products')
Spree.routes.product_search = Spree.pathFor('admin/search/products')
Spree.routes.shipments_api = Spree.pathFor('api/shipments')
Spree.routes.checkouts_api = Spree.pathFor('api/checkouts')
Spree.routes.stock_locations_api = Spree.pathFor('api/stock_locations')
Spree.routes.taxon_products_api = Spree.pathFor('api/taxons/products')
Spree.routes.taxons_search = Spree.pathFor('api/taxons')
Spree.routes.user_search = Spree.pathFor('admin/search/users')
Spree.routes.variants_api = Spree.pathFor('api/variants')

Spree.routes.edit_product = function(product_id) {
  return Spree.pathFor('admin/products/' + product_id + '/edit')
}

Spree.routes.payments_api = function(order_id) {
  return Spree.pathFor('api/orders/' + order_id + '/payments')
}

Spree.routes.stock_items_api = function(stock_location_id) {
  return Spree.pathFor('api/stock_locations/' + stock_location_id + '/stock_items')
}
