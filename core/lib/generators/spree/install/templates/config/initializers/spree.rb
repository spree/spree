# Configure Spree Preferences
#
# Note: Initializing preferences available within the Admin will overwrite any changes that were made through the user interface when you restart.
#       If you would like users to be able to update a setting with the Admin it should NOT be set here.
#
# Note: If a preference is set here it will be stored within the cache & database upon initialization.
#       Just removing an entry from this initializer will not make the preference value go away.
#       Instead you must either set a new value or remove entry, clear cache, and remove database entry.
#
# In order to initialize a setting do:
# config.setting_name = 'new value'
#
# More on configuring Spree preferences can be found at:
# https://docs.spreecommerce.org/developer/customization
Spree.config do |config|
  # Example:
  # Uncomment to stop tracking inventory levels in the application
  # config.track_inventory_levels = false
end

# Use a CDN host for images, eg. Cloudfront
# This is used in the frontend to generate absolute URLs to images
# Default is nil and your application host will be used
# Spree.cdn_host = 'cdn.example.com'

# Use a different service for storage (S3, google, etc)
# unless Rails.env.test?
#   Spree.private_storage_service_name = :amazon_public # public assets, such as product images
#   Spree.public_storage_service_name = :amazon_private # private assets, such as invoices, etc
# end

# Use a different search engine for products
# You can check the default search class at:
# https://github.com/spree/spree/blob/main/core/lib/spree/core/search/base.rb
# and use it as base class for your custom searcher
# eg. MySearcher < Spree::Core::Search::Base
# Spree.searcher_class = 'MySearcher'

# Configure Spree Dependencies
#
# Note: If a dependency is set here it will NOT be stored within the cache & database upon initialization.
#       Just removing an entry from this initializer will make the dependency value go away.
#
# More on how to use Spree dependencies can be found at:
# https://docs.spreecommerce.org/customization/dependencies
Spree.dependencies do |dependencies|
  # Example:
  # Uncomment to change the default Service handling adding Items to Cart
  # dependencies.cart_add_item_service = 'MyNewAwesomeService'
end

# Spree::Api::Dependencies.storefront_cart_serializer = 'MyRailsApp::CartSerializer'

Spree.user_class = <%= (options[:user_class].blank? ? 'Spree::LegacyUser' : options[:user_class]).inspect %>
# Use a different class for admin users
# Spree.admin_user_class = 'AdminUser'
