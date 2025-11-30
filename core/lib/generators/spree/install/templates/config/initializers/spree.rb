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

# Background job queue names
# Spree.queues.default = :default
# Spree.queues.variants = :default
# Spree.queues.stock_location_stock_items = :default
# Spree.queues.coupon_codes = :default

# Use a CDN host for images, eg. Cloudfront
# This is used in the frontend to generate absolute URLs to images
# Default is nil and your application host will be used
# Spree.cdn_host = 'cdn.example.com'

# Multi-store setup
# You need to set a wildcard `root_domain` on the store to enable multi-store setup
# all new stores will be created in a subdomain of the root domain, eg. store1.lvh.me, store2.lvh.me, etc.
# Spree.root_domain = ENV.fetch('SPREE_ROOT_DOMAIN', 'lvh.me')

# Use a different service for storage (S3, google, etc)
# unless Rails.env.test?
#   Spree.private_storage_service_name = :amazon_public # public assets, such as product images
#   Spree.public_storage_service_name = :amazon_private # private assets, such as invoices, etc
# end

# Enable theme preview screenshots in admin dashboard
# Spree.screenshot_api_token = <Your Screenshot API token obtained from https://screenshotapi.net/>

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

# uncomment lines below to add your own custom business logic
# such as promotions, shipping methods, etc
Rails.application.config.after_initialize do
  # Payment methods and shipping calculators
  # Spree.payment_methods << Spree::PaymentMethods::VerySafeAndReliablePaymentMethod
  # Spree.calculators.shipping_methods << Spree::ShippingMethods::SuperExpensiveNotVeryFastShipping
  # Spree.calculators.tax_rates << Spree::TaxRates::FinanceTeamForcedMeToCodeThis

  # Stock splitters and adjusters
  # Spree.stock_splitters << Spree::Stock::Splitters::SecretLogicSplitter
  # Spree.adjusters << Spree::Adjustable::Adjuster::TaxTheRich

  # Custom promotions
  # Spree.calculators.promotion_actions_create_adjustments << Spree::Calculators::PromotionActions::CreateAdjustments::AddDiscountForFriends
  # Spree.calculators.promotion_actions_create_item_adjustments << Spree::Calculators::PromotionActions::CreateItemAdjustments::FinanceTeamForcedMeToCodeThis
  # Spree.promotions.rules << Spree::Promotions::Rules::OnlyForVIPCustomers
  # Spree.promotions.actions << Spree::Promotions::Actions::GiftWithPurchase

  # Taxon rules
  # Spree.taxon_rules << Spree::TaxonRules::ProductsWithColor

  # Exports and reports
  # Spree.export_types << Spree::Exports::Payments
  # Spree.reports << Spree::Reports::MassivelyOvercomplexReportForCfo

  # Page builder (themes, pages, sections, blocks)
  # Spree.page_builder.themes << Spree::Themes::NewShinyTheme
  # Spree.page_builder.theme_layout_sections << Spree::PageSections::SuperImportantCeoBio
  # Spree.page_builder.pages << Spree::Pages::CustomLandingPage
  # Spree.page_builder.page_sections << Spree::PageSections::ContactFormToGetInTouch
  # Spree.page_builder.page_blocks << Spree::PageBlocks::BigRedButtonToCallSales

  # Storefront partials
  # Spree.storefront.partials.head << 'spree/shared/that_js_snippet_that_marketing_forced_me_to_include'

  # Admin partials
  # Spree.admin.partials.product_form << 'spree/admin/products/custom_section'

  # Role-based permissions
  # Configure which permission sets are assigned to each role
  # More on permission sets: https://spreecommerce.org/docs/developer/customization/permissions
  Spree.permissions.assign(:default, [Spree::PermissionSets::DefaultCustomer])
  Spree.permissions.assign(:admin, [Spree::PermissionSets::SuperUser])

  # Example: Create a custom role with specific permissions
  # Spree.permissions.assign(:customer_service, [
  #   Spree::PermissionSets::DashboardDisplay,
  #   Spree::PermissionSets::OrderManagement,
  #   Spree::PermissionSets::UserDisplay
  # ])
  #
  # Available permission sets:
  # - Spree::PermissionSets::SuperUser (full admin access)
  # - Spree::PermissionSets::DefaultCustomer (storefront access)
  # - Spree::PermissionSets::DashboardDisplay (view admin dashboard)
  # - Spree::PermissionSets::OrderDisplay / OrderManagement
  # - Spree::PermissionSets::ProductDisplay / ProductManagement
  # - Spree::PermissionSets::UserDisplay / UserManagement
  # - Spree::PermissionSets::StockDisplay / StockManagement
  # - Spree::PermissionSets::PromotionManagement
  # - Spree::PermissionSets::ConfigurationManagement
  # - Spree::PermissionSets::RoleManagement
end

Spree.user_class = <%= (options[:user_class].blank? ? 'Spree::LegacyUser' : options[:user_class]).inspect %>
Spree.admin_user_class = <%= (options[:admin_user_class].blank? ? (options[:user_class].blank? ? 'Spree::LegacyUser' : options[:user_class]) : options[:admin_user_class]).inspect %>
