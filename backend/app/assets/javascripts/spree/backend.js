//= require modernizr
//= require purify
//= require sortable
//= require flatpickr
//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require handlebars
//= require cleave
//= require js.cookie
//= require jquery.jstree/jquery.jstree
//= require jquery_ujs
//= require jquery-ui/widgets/autocomplete
//= require select2-full
//= require sweetalert2
//= require underscore-min.js
//= require jsonapi-serializer.min

//= require spree/backend/global/alerts
//= require spree/backend/global/bootstrap
//= require spree/backend/global/flatpickr
//= require spree/backend/global/ransack
//= require spree/backend/global/radio_panel_toggle
//= require spree/backend/global/responsive_menus
//= require spree/backend/global/sortable

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
//= require spree/backend/multi_currency
//= require spree/backend/option_type_autocomplete
//= require spree/backend/option_value_picker
//= require spree/backend/orders/edit
//= require spree/backend/payments/edit
//= require spree/backend/payments/new
//= require spree/backend/product_picker
//= require spree/backend/progress
//= require spree/backend/promotions
//= require spree/backend/returns/expedited_exchanges_warning
//= require spree/backend/returns/return_item_selection
//= require spree/backend/shipments
//= require spree/backend/states
//= require spree/backend/stock_location
//= require spree/backend/stock_management
//= require spree/backend/stock_movement
//= require spree/backend/stock_transfer
//= require spree/backend/taxon_autocomplete
//= require spree/backend/taxon_permalink_preview
//= require spree/backend/taxon_tree_menu
//= require spree/backend/taxonomy
//= require spree/backend/taxons
//= require spree/backend/users/edit
//= require spree/backend/user_picker
//= require spree/backend/variant_autocomplete
//= require spree/backend/variant_management
//= require spree/backend/zone

Spree.routes.clear_cache = Spree.adminPathFor('general_settings/clear_cache')
Spree.routes.checkouts_api = Spree.pathFor('api/v1/checkouts')
Spree.routes.classifications_api = Spree.pathFor('api/v1/classifications')
Spree.routes.option_types_api = Spree.pathFor('api/v1/option_types')
Spree.routes.option_values_api = Spree.pathFor('api/v1/option_values')
Spree.routes.orders_api = Spree.pathFor('api/v1/orders')
Spree.routes.products_api = Spree.pathFor('api/v1/products')
Spree.routes.shipments_api = Spree.pathFor('api/v1/shipments')
Spree.routes.checkouts_api = Spree.pathFor('api/v1/checkouts')
Spree.routes.stock_locations_api = Spree.pathFor('api/v1/stock_locations')
Spree.routes.taxon_products_api = Spree.pathFor('api/v1/taxons/products')
Spree.routes.taxons_api = Spree.pathFor('api/v1/taxons')
Spree.routes.users_api = Spree.pathFor('api/v1/users')
Spree.routes.variants_api = Spree.pathFor('api/v1/variants')

Spree.routes.edit_product = function (productId) {
  return Spree.adminPathFor('products/' + productId + '/edit')
}

Spree.routes.payments_api = function (orderId) {
  return Spree.pathFor('api/v1/orders/' + orderId + '/payments')
}

Spree.routes.stock_items_api = function (stockLocationId) {
  return Spree.pathFor('api/v1/stock_locations/' + stockLocationId + '/stock_items')
}

// API v2

Spree.routes.countries_api_v2 = Spree.pathFor('api/v2/platform/countries')

Spree.routes.option_types_api_v2 = Spree.pathFor('api/v2/platform/option_types')
Spree.routes.option_values_api_v2 = Spree.pathFor('api/v2/platform/option_values')

Spree.routes.users_api_v2 = Spree.pathFor('api/v2/platform/users')

Spree.apiV2Authentication = function() {
  return {
    'Authorization': 'Bearer ' + OAUTH_TOKEN
  }
}
