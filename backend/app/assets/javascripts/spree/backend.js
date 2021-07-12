// 3rd party JavaScript libraries
//= require cleave
//= require flatpickr
//= require handlebars
//= require js.cookie
//= require jsonapi-serializer.min
//= require modernizr
//= require popper
//= require purify
//= require rails-ujs
//= require sortable
//= require sweetalert2
//= require underscore-min.js

// 3rd party JavaScript libraries requiring jQuery
//= require jquery3
//= require bootstrap-sprockets
//= require jquery.jstree/jquery.jstree
//= require jquery-ui/widgets/autocomplete
//= require select2-full

// Spree JavaScript
//= require spree
//= require spree/backend/spree-select2
//= require spree/backend/address_states
//= require spree/backend/admin
//= require spree/backend/global/_index
//= require spree/backend/calculator
//= require spree/backend/checkouts/edit
//= require spree/backend/gateway
//= require spree/backend/general_settings
//= require spree/backend/handlebar_extensions
//= require spree/backend/multi_currency
//= require spree/backend/option_type_autocomplete
//= require spree/backend/option_value_picker
//= require spree/backend/orders/_index
//= require spree/backend/payments/edit
//= require spree/backend/payments/new
//= require spree/backend/product_picker
//= require spree/backend/progress
//= require spree/backend/promotions
//= require spree/backend/cms/_index
//= require spree/backend/menus/_index
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
//= require spree/backend/variants/_index
//= require spree/backend/zone

// API v1
Spree.routes.clear_cache = Spree.adminPathFor('general_settings/clear_cache')
Spree.routes.checkouts_api = Spree.pathFor('api/v1/checkouts')
Spree.routes.classifications_api = Spree.pathFor('api/v1/classifications')
Spree.routes.option_types_api = Spree.pathFor('api/v1/option_types')
Spree.routes.option_values_api = Spree.pathFor('api/v1/option_values')
Spree.routes.orders_api = Spree.pathFor('api/v1/orders')
Spree.routes.products_api = Spree.pathFor('api/v1/products')
Spree.routes.shipments_api = Spree.pathFor('api/v1/shipments')
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
Spree.routes.classifications_api_v2 = Spree.pathFor('api/v2/platform/classifications')
Spree.routes.menus_api_v2 = Spree.pathFor('api/v2/platform/menus')
Spree.routes.menus_items_api_v2 = Spree.pathFor('api/v2/platform/menu_items')
Spree.routes.option_types_api_v2 = Spree.pathFor('api/v2/platform/option_types')
Spree.routes.option_values_api_v2 = Spree.pathFor('api/v2/platform/option_values')
Spree.routes.orders_api_v2 = Spree.pathFor('api/v2/platform/orders')
Spree.routes.products_api_v2 = Spree.pathFor('/api/v2/platform/products')
Spree.routes.taxons_api_v2 = Spree.pathFor('/api/v2/platform/taxons')
Spree.routes.users_api_v2 = Spree.pathFor('api/v2/platform/users')

Spree.apiV2Authentication = function() {
  return {
    Authorization: 'Bearer ' + OAUTH_TOKEN
  }
}
