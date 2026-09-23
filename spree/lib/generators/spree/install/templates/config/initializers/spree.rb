# Spree settings are configured with environment variables — see
# https://docs.spreecommerce.org/developer/customization/configuration
# for every setting and the variable that sets it.
#
#   SPREE_MINIMUM_PASSWORD_LENGTH=10
#
# Anything that shapes how a shop sells — currency, taxes, when customers are
# charged — belongs to the store and is edited in the dashboard, not here.
#
# Use a Spree.config block only for a value that has to be computed in Ruby;
# it is applied at boot and wins over the environment.
#
# Spree.config do |config|
#   config.minimum_password_length = 10
# end

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
#   Spree.public_storage_service_name = :amazon_public   # public assets, such as product images
#   Spree.private_storage_service_name = :amazon_private # private assets, such as invoices, etc
# end

# Swap a Spree service for your own — see
# https://docs.spreecommerce.org/developer/customization/dependencies
Spree.dependencies do |dependencies|
  # Example:
  # Uncomment to change the default Service handling adding Items to Cart
  # dependencies.cart_add_item_service = 'MyNewAwesomeService'
end

# Spree.api.cart_serializer = 'MyRailsApp::CartSerializer'

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

  # Collection rules
  # Rails.application.config.spree.collection_rules << Spree::CollectionRules::ProductsWithColor

  # Exports
  # Spree.export_types << Spree::Exports::Payments

  # Role-based permissions
  # Staff roles and their permissions are managed as data — in the dashboard
  # (Settings → Roles), via the Admin API, or in db/seeds.rb:
  #
  #   Spree::Store.default.roles.find_or_create_by!(name: 'support')
  #     .update!(permissions: %w[read_orders read_customers])
  #
  # Extensions can register additional permission resources:
  # Spree.permissions.register_scope(:reviews, group: :catalog, resources: -> { [MyApp::Review] })
  #
  # More: https://spreecommerce.org/docs/developer/customization/permissions
end

# Background job queue configuration
# Spree.queues.addresses = :default
# Spree.queues.api_keys = :default
# Spree.queues.categories = :default
# Spree.queues.collections = :default
# Spree.queues.coupon_codes = :default
# Spree.queues.data_requests = :default
# Spree.queues.default = :default
# Spree.queues.events = :default
# Spree.queues.exports = :default
# Spree.queues.gift_cards = :default
# Spree.queues.images = :default
# Spree.queues.imports = :default
# Spree.queues.payment_webhooks = :default
# Spree.queues.payouts = :default
# Spree.queues.products = :default
# Spree.queues.search = :default
# Spree.queues.stock_location_stock_levels = :default
# Spree.queues.stock_reservations = :default
# Spree.queues.tax_identifiers = :default
# Spree.queues.themes = :default
# Spree.queues.variants = :default
# Spree.queues.webhooks = :default

# Search provider — requires the spree_meilisearch gem
# Spree.search_provider = 'SpreeMeilisearch::SearchProvider'

Spree.customer_class = <%= (options[:user_class].blank? ? 'Spree::Customer' : options[:user_class]).inspect %>
Spree.admin_user_class = <%= (options[:admin_user_class].blank? ? (options[:user_class].blank? ? 'Spree::AdminUser' : options[:user_class]) : options[:admin_user_class]).inspect %>
