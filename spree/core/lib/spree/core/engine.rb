require_relative 'dependencies'
require_relative 'configuration'

module Spree
  module Core
    class Engine < ::Rails::Engine
      Environment = Struct.new(:calculators,
                               :validators,
                               :preferences,
                               :dependencies,
                               :payment_methods,
                               :adjusters,
                               :media_viewable_types,
                               :default_tax_provider,
                               :tax_providers,
                               :pricing_providers,
                               :inventory_providers,
                               :password_validator,
                               :fulfillment_providers,
                               :tracking_carriers,
                               :stock_splitters,
                               :commission_rules,
                               :delivery_method_rules,
                               :seller_requirements,
                               :delivery_rate_providers,
                               :digital_asset_providers,
                               :delivery_profile_types,
                               :order_routing,
                               :promotions,
                               :pricing,
                               :line_item_comparison_hooks,
                               :data_feed_types,
                               :export_types,
                               :import_types,
                               :taxon_rules,
                               :collection_rules,
                               :time_based_collection_rules,
                               :themes,
                               :theme_layout_sections,
                               :pages,
                               :page_sections,
                               :page_blocks,
                               :reports,
                               :translatable_resources,
                               :taggable_types,
                               :custom_fields,
                               :analytics_events,
                               :analytics_event_handlers,
                               :integrations,
                               :number_generators,
                               :subscribers,
                               :store_authentication_strategies,
                               :admin_authentication_strategies,
                               :seller_authentication_strategies)
      SpreeCalculators = Struct.new(:shipping_methods, :tax_rates, :promotion_actions_create_adjustments, :promotion_actions_create_item_adjustments)
      PromoEnvironment = Struct.new(:rules, :actions)
      PricingEnvironment = Struct.new(:rules)
      OrderRoutingEnvironment = Struct.new(:strategies, :rules)
      # Spree::Validators, not a Struct: the sets carry register/unregister so
      # a host can drop a core rule (see Spree.validators.addresses).
      SpreeValidators = Spree::Validators
      CustomFieldsEnvironment = Struct.new(:types, :enabled_resources)
      isolate_namespace Spree
      engine_name 'spree'

      # Add app/subscribers to autoload paths
      config.paths.add 'app/subscribers', eager_load: true

      # Register bundled ActionMailer previews so they show up at /rails/mailers
      # without the host app having to copy any files.
      initializer 'spree.mailer_previews' do |app|
        if app.config.action_mailer.show_previews
          app.config.action_mailer.preview_paths << File.expand_path('previews', __dir__)
        end
      end

      initializer 'spree.environment', before: :load_config_initializers do |app|
        app.config.spree = Environment.new(SpreeCalculators.new, SpreeValidators.new, Spree::Core::Configuration.new, Spree::Core::Dependencies.new)

        app.config.active_record.yaml_column_permitted_classes ||= []
        app.config.active_record.yaml_column_permitted_classes.concat([Symbol, BigDecimal, ActiveSupport::HashWithIndifferentAccess, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Time])
        Spree::Config = app.config.spree.preferences
        Spree::RuntimeConfig = app.config.spree.preferences # for compatibility
        Spree::Dependencies = app.config.spree.dependencies
        Spree::Deprecation = ActiveSupport::Deprecation.new('6.0', 'Spree')
      end

      # I18n's config lives in fiber/thread-local storage that survives across
      # requests on reused server threads, so a request that never assigns its
      # own locale would render in whatever locale the previous request on the
      # same thread set. The i18n gem ships a middleware that resets it after
      # every request; Rails does not install it by default. Mobility's request
      # state needs no counterpart here — Mobility.locale and Spree's
      # Mobility.store_based_fallbacks live in RequestStore, which is cleared
      # per request by request_store's own middleware.
      initializer 'spree.locale_state_reset' do |app|
        app.middleware.use ::I18n::Middleware
      end

      initializer 'spree.register.subscribers', before: :load_config_initializers do |app|
        # Initialize subscribers array early so engines can add subscribers via initializers
        app.config.spree.subscribers = []
      end

      initializer 'spree.register.calculators', before: :after_initialize do |app|
      end

      # Seeded before application initializers so a host's
      # `config/initializers/spree.rb` can register custom generators.
      initializer 'spree.register.number_generators', before: :load_config_initializers do |app|
        app.config.spree.number_generators = Spree::NumberGenerators::Registry.new
      end

      initializer 'spree.register.stock_splitters', before: :load_config_initializers do |app|
      end

      initializer 'spree.register.line_item_comparison_hooks', before: :load_config_initializers do |app|
        app.config.spree.line_item_comparison_hooks = Set.new
      end

      initializer 'spree.register.payment_methods', after: 'acts_as_list.insert_into_active_record' do |app|
      end

      initializer 'spree.register.adjustable_adjusters' do |app|
      end

      # Seed the order routing registries early so engines and apps can append
      # their own strategies / rule kinds from initializer files. Core's defaults
      # are concatenated in after_initialize below.
      initializer 'spree.register.order_routing', before: :load_config_initializers do |app|
        app.config.spree.order_routing = OrderRoutingEnvironment.new
        app.config.spree.order_routing.strategies = []
        app.config.spree.order_routing.rules = []
      end

      # Seeded early for the same reason as order routing: initializer files
      # append custom rule kinds. Core defaults concatenate in after_initialize.
      initializer 'spree.register.commission_rules', before: :load_config_initializers do |app|
        app.config.spree.commission_rules = []
      end

      initializer 'spree.register.delivery_method_rules', before: :load_config_initializers do |app|
        app.config.spree.delivery_method_rules = []
      end

      # Seeded early like the other kind registries: an initializer file adds
      # a marketplace's own requirement kinds, core's concatenate after.
      initializer 'spree.register.seller_requirements', before: :load_config_initializers do |app|
        app.config.spree.seller_requirements = []
      end

      initializer 'spree.register.delivery_rate_providers', before: :load_config_initializers do |app|
        app.config.spree.delivery_rate_providers = []
      end

      # Same reason again: a tax provider gem, or a host app, registers its
      # engine from an initializer file. Core's Internal concatenates below.
      initializer 'spree.register.tax_providers', before: :load_config_initializers do |app|
        app.config.spree.tax_providers = []
      end

      # Same reason as the tax providers above: a connector gem registers its
      # engine from an initializer file, and core's Internal concatenates below.
      initializer 'spree.register.pricing_providers', before: :load_config_initializers do |app|
        app.config.spree.pricing_providers = []
      end

      initializer 'spree.register.inventory_providers', before: :load_config_initializers do |app|
        app.config.spree.inventory_providers = []
      end

      initializer 'spree.register.digital_asset_providers', before: :load_config_initializers do |app|
        app.config.spree.digital_asset_providers = []
      end

      initializer 'spree.register.delivery_profile_types', before: :load_config_initializers do |app|
        app.config.spree.delivery_profile_types = []
      end

      initializer 'spree.register.custom_fields' do |app|
        app.config.spree.custom_fields = CustomFieldsEnvironment.new
        app.config.spree.custom_fields.types = []
        app.config.spree.custom_fields.enabled_resources = []
      end

      # We need to define promotions rules here so extensions and existing apps
      # can add their custom classes on their initializer files
      initializer 'spree.promo.environment' do |app|
        app.config.spree.promotions = PromoEnvironment.new
        app.config.spree.promotions.rules = []
      end

      initializer 'spree.promo.register.promotion.calculators' do |app|
      end

      # Pricing configuration for price lists and price rules
      initializer 'spree.pricing.environment', after: 'spree.environment' do |app|
        app.config.spree.pricing = PricingEnvironment.new
        app.config.spree.pricing.rules = []
      end

      # Country and subdivision names are translated by the countries gem, which
      # only loads the locales it is told about. This runs after initialization
      # because Spree.available_locales reads i18n configuration that is not
      # populated while initializers are still running.
      config.after_initialize do
        ISO3166.configure do |iso_config|
          iso_config.locales = (Spree.available_locales.map { |locale| locale.to_s.downcase } << 'en').uniq
        end

        Spree::IsoData.reset!
      end

      # Promotion rules need to be evaluated on after initialize otherwise
      # Spree.customer_class would be nil and users might experience errors related
      # to malformed model associations (Spree.customer_class is only defined on
      # the app initializer)
      config.after_initialize do
        Rails.application.config.spree.calculators.shipping_methods = [
          Spree::Calculator::Shipping::FlatPercentItemTotal,
          Spree::Calculator::Shipping::FlatRate,
          Spree::Calculator::Shipping::FlexiRate,
          Spree::Calculator::Shipping::PerItem,
          Spree::Calculator::Shipping::PriceSack,
          Spree::Calculator::Shipping::DigitalDelivery,
        ]

        Rails.application.config.spree.stock_splitters = [
          Spree::Stock::Splitter::DeliveryProfile,
          Spree::Stock::Splitter::Backordered
        ]

        Rails.application.config.spree.payment_methods = [
          Spree::Gateway::Bogus,
          Spree::Gateway::CustomPaymentSourceMethod,
          Spree::PaymentMethod::Check,
          Spree::PaymentMethod::StoreCredit
        ]

        Rails.application.config.spree.adjusters = [
          Spree::Adjusters::Promotion
        ]

        # What a media file can be placed on. The polymorphic viewable column
        # would otherwise accept any constant name, and everything downstream —
        # store resolution, counter caches, the usage panel — reasons about the
        # registered set. An extension placing media on its own model appends
        # to this from an initializer.
        Rails.application.config.spree.media_viewable_types = %w[
          Spree::Product
          Spree::Variant
          Spree::Category
          Spree::Collection
        ]


        # The fallback engine when a market names none (see docs/plans/6.0-tax-provider.md).
        # Assigned only if an initializer file has not already named one — an app
        # that picks its own default must keep it.
        Rails.application.config.spree.default_tax_provider ||= Spree::TaxProvider::Internal

        # Engines a market can select. Concatenated, not assigned: provider gems
        # and host apps append theirs from initializer files, which run first.
        Rails.application.config.spree.tax_providers.concat [Spree::TaxProvider::Internal]

        # Pricing and inventory sources. Internal is Spree's own catalog and
        # stock records; connector gems append theirs so a merchant picks from
        # what is installed (see docs/plans/6.0-third-party-pricing-inventory.md).
        Rails.application.config.spree.pricing_providers.concat [Spree::PricingProvider::Internal]
        Rails.application.config.spree.inventory_providers.concat [Spree::InventoryProvider::Internal]

        # Password policy for the default auth models. Swap for corporate rules,
        # breach-list lookups or entropy scoring.
        Rails.application.config.spree.password_validator = Spree::PasswordLengthValidator

        Rails.application.config.spree.fulfillment_providers = [
          Spree::FulfillmentProvider::Manual,
          Spree::FulfillmentProvider::Digital,
          Spree::FulfillmentProvider::Pickup,
          Spree::FulfillmentProvider::PickupPoint
        ]

        # Carriers a merchant can pin a tracking number to, with the public
        # tracking page each one offers (`:tracking` is the placeholder).
        # Hosts and extensions add their own:
        #   Spree.tracking_carriers['my_courier'] = { name: '...', url: '...' }
        # Slugs match the tracking_number gem's courier codes where both know
        # the carrier, so a number auto-detected from its format lands on the
        # same entry a merchant would have picked by hand.
        Rails.application.config.spree.tracking_carriers = {
          'ups' => { name: 'UPS', url: 'https://www.ups.com/track?tracknum=:tracking' },
          'usps' => { name: 'USPS', url: 'https://tools.usps.com/go/TrackConfirmAction?tLabels=:tracking' },
          'fedex' => { name: 'FedEx', url: 'https://www.fedex.com/fedextrack/?trknbr=:tracking' },
          'dhl' => { name: 'DHL Express', url: 'https://www.dhl.com/global-en/home/tracking.html?tracking-id=:tracking' },
          'dpd' => { name: 'DPD', url: 'https://tracking.dpd.de/status/en_US/parcel/:tracking' },
          'gls' => { name: 'GLS', url: 'https://gls-group.eu/EU/en/parcel-tracking?match=:tracking' },
          'inpost' => { name: 'InPost', url: 'https://inpost.pl/sledzenie-przesylek?number=:tracking' },
          'royal_mail' => { name: 'Royal Mail', url: 'https://www.royalmail.com/track-your-item#/tracking-results/:tracking' },
          'evri' => { name: 'Evri', url: 'https://www.evri.com/track/parcel/:tracking' },
          'canada_post' => { name: 'Canada Post', url: 'https://www.canadapost-postescanada.ca/track-reperage/en#/search?searchFor=:tracking' },
          'australia_post' => { name: 'Australia Post', url: 'https://auspost.com.au/mypost/track/#/details/:tracking' },
          'postnl' => { name: 'PostNL', url: 'https://jouw.postnl.nl/track-and-trace/:tracking' },
          'colissimo' => { name: 'Colissimo', url: 'https://www.laposte.fr/outils/suivre-vos-envois?code=:tracking' },
          'chronopost' => { name: 'Chronopost', url: 'https://www.chronopost.fr/tracking-no-cms/suivi-page?listeNumerosLT=:tracking' },
          'poczta_polska' => { name: 'Poczta Polska', url: 'https://emonitoring.poczta-polska.pl/?numer=:tracking' },
          'deutsche_post' => { name: 'Deutsche Post DHL', url: 'https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=:tracking' }
        }


        # Quoting strategies selectable on a delivery method. Internal prices
        # through the method's calculator; carrier gems append theirs.
        Rails.application.config.spree.delivery_rate_providers.concat [
          Spree::DeliveryRateProvider::Internal
        ]

        # Digital asset sources. Core ships the uploaded-file default; host
        # apps append providers that resolve a deliverable elsewhere.
        Rails.application.config.spree.digital_asset_providers.concat [
          Spree::DigitalAssetProvider::File
        ]

        # Profile kinds selectable when creating a delivery profile;
        # extension kinds append theirs.
        Rails.application.config.spree.delivery_profile_types.concat [
          Spree::DeliveryProfiles::Shipping,
          Spree::DeliveryProfiles::Digital
        ]

        # Selectable order routing strategies. The internal Reducer collaborator
        # is intentionally NOT listed — it is not a Strategy::Base. Plugins add
        # their own via this array.
        Rails.application.config.spree.order_routing.strategies.concat [
          Spree::OrderRouting::Strategy::Rules
        ]

        # Available order routing rule kinds. STI dispatches at runtime via the
        # +type+ column; this array is the curated allowlist that drives admin
        # pickers and the rule +type+ validation. Plugins append their own.
        Rails.application.config.spree.order_routing.rules.concat [
          Spree::OrderRouting::Rules::PreferredLocation,
          Spree::OrderRouting::Rules::MinimizeSplits,
          Spree::OrderRouting::Rules::DefaultLocation
        ]

        # Commission targeting rule kinds (docs/plans/6.0-multi-vendor-marketplace.md).
        Rails.application.config.spree.commission_rules.concat [
          Spree::CommissionRules::SellerRule,
          Spree::CommissionRules::CategoryRule,
          Spree::CommissionRules::ProductRule,
          Spree::CommissionRules::ItemTotalRule
        ]

        # Seller onboarding requirement kinds
        # (docs/plans/6.0-seller-onboarding-requirements.md).
        Rails.application.config.spree.seller_requirements.concat [
          Spree::SellerRequirements::AcceptTerms,
          Spree::SellerRequirements::CompleteProfile,
          Spree::SellerRequirements::BillingAddress,
          Spree::SellerRequirements::ReturnsAddress,
          Spree::SellerRequirements::MinimumProducts,
          Spree::SellerRequirements::RequiredCustomFields,
          Spree::SellerRequirements::Policy,
          Spree::SellerRequirements::Attestation,
          Spree::SellerRequirements::OperatorReview,
          Spree::SellerRequirements::Document
        ]

        # Delivery-method eligibility rule kinds (docs/plans/6.0-delivery-method-rules.md).
        Rails.application.config.spree.delivery_method_rules.concat [
          Spree::DeliveryMethodRules::ItemTotalRule,
          Spree::DeliveryMethodRules::WeightRule,
          Spree::DeliveryMethodRules::ExcludedProductsRule,
          Spree::DeliveryMethodRules::ChannelRule
        ]

        Rails.application.config.spree.calculators.promotion_actions_create_adjustments = [
          Spree::Calculator::FlatPercentItemTotal,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate,
          Spree::Calculator::TieredPercent,
          Spree::Calculator::TieredFlatRate
        ]

        Rails.application.config.spree.calculators.promotion_actions_create_item_adjustments = [
          Spree::Calculator::PercentOnLineItem,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate
        ]

        Rails.application.config.spree.promotions.rules.concat [
          Spree::Promotion::Rules::Currency,
          Spree::Promotion::Rules::Country,
          Spree::Promotion::Rules::Channel,
          Spree::Promotion::Rules::Market,
          Spree::Promotion::Rules::ItemTotal,
          Spree::Promotion::Rules::Product,
          Spree::Promotion::Rules::User,
          Spree::Promotion::Rules::CustomerGroup,
          Spree::Promotion::Rules::FirstOrder,
          Spree::Promotion::Rules::UserLoggedIn,
          Spree::Promotion::Rules::OneUsePerUser,
          Spree::Promotion::Rules::Category,
          Spree::Promotion::Rules::OptionValue,
        ]

        # Default registry. MarketRule is the only geography rule: price
        # lists that were zone-scoped before 6.0 are converted onto it by
        # `spree:migrate_tax_zones` where the countries match a market, and
        # deactivated with a report where they don't.
        Rails.application.config.spree.pricing.rules.concat [
          Spree::PriceRules::UserRule,
          Spree::PriceRules::CustomerGroupRule,
          Spree::PriceRules::VolumeRule,
          Spree::PriceRules::MarketRule,
          Spree::PriceRules::ChannelRule
        ]

        Rails.application.config.spree.promotions.actions = [
          Promotion::Actions::CreateAdjustment,
          Promotion::Actions::CreateItemAdjustments,
          Promotion::Actions::CreateLineItems,
          Promotion::Actions::FreeShipping
        ]

        Rails.application.config.spree.data_feed_types = [
          Spree::DataFeed::Google
        ]

        Rails.application.config.spree.export_types = [
          Spree::Exports::Products,
          Spree::Exports::ProductTranslations,
          Spree::Exports::Orders,
          Spree::Exports::Customers,
          Spree::Exports::GiftCards,
          Spree::Exports::NewsletterSubscribers,
          Spree::Exports::CouponCodes
        ]

        Rails.application.config.spree.import_types = [
          Spree::Imports::Products,
          Spree::Imports::ProductTranslations,
          Spree::Imports::Customers,
        ]

        Rails.application.config.spree.taxon_rules = [
          Spree::TaxonRules::Tag,
          Spree::TaxonRules::AvailableOn,
          Spree::TaxonRules::Sale,
        ]

        # Mirrors config.spree.taxon_rules above. AvailableOn ships with an interim
        # legacy-column implementation; its channel-aware rewrite is a later phase
        # (see docs/plans/6.0-replace-taxons-with-categories.md → Migration Phase 5).
        Rails.application.config.spree.collection_rules = [
          Spree::CollectionRules::Tag,
          Spree::CollectionRules::AvailableOn,
          Spree::CollectionRules::Sale,
        ]

        # Net-new (no taxon_rules equivalent — taxons ship no scheduled refresh).
        # Drives Spree::Collections::RegenerateTimeBasedJob.
        Rails.application.config.spree.time_based_collection_rules = [
          Spree::CollectionRules::AvailableOn,
        ]

        Rails.application.config.spree.reports = [
          Spree::Reports::ProductsPerformance,
          Spree::Reports::SalesTotal
        ]

        Rails.application.config.spree.translatable_resources = [
          Spree::OptionType,
          Spree::OptionValue,
          Spree::Product,
          Spree::ProductType,
          Spree::Collection,
          Spree::Category,
          Spree::Store,
          Spree::Policy,
          Spree::Seller
        ]

        # Resources that expose tags via `acts_as_taggable_on :tags`. The
        # Admin API's `/tags` autocomplete endpoint accepts these as
        # `taggable_type`, and the SPA `<TagCombobox>` targets them by name.
        # Extend in an app initializer (after :load_config_initializers) to
        # surface custom taggables — e.g.
        #   Rails.application.config.spree.taggable_types << 'MyApp::Seller'.
        Rails.application.config.spree.taggable_types = [
          'Spree::Product',
          'Spree::Order',
          Spree.customer_class.to_s
        ]

        Rails.application.config.spree.custom_fields.types = [
          Spree::CustomFields::ShortText,
          Spree::CustomFields::LongText,
          Spree::CustomFields::RichText,
          Spree::CustomFields::Number,
          Spree::CustomFields::Boolean,
          Spree::CustomFields::Json
        ]

        Rails.application.config.spree.custom_fields.enabled_resources = [
          Spree::Address,
          Spree::Claim,
          Spree::Collection,
          Spree::CreditCard,
          Spree::Exchange,
          Spree::GiftCard,
          Spree::LineItem,
          Spree::Media,
          Spree::NewsletterSubscriber,
          Spree::OptionType,
          Spree::OptionValue,
          Spree::Order,
          Spree::Payment,
          Spree::PaymentMethod,
          Spree::PaymentSource,
          Spree::Product,
          Spree::ProductType,
          Spree::Promotion,
          Spree::Refund,
          Spree::Return,
          Spree::Fulfillment,
          Spree::DeliveryMethod,
          Spree::StockLevel,
          Spree::StockTransfer,
          Spree::Store,
          Spree::StoreCredit,
          Spree::TaxRate,
          Spree::Category,
          Spree::Variant,
          Spree::Seller,
          Spree.customer_class
        ]

        Rails.application.config.spree.analytics_events = {
          product_viewed: 'Product Viewed',
          product_list_viewed: 'Product List Viewed',
          product_searched: 'Product Searched',
          product_added: 'Product Added',
          product_removed: 'Product Removed',

          product_added_to_wishlist: 'Product Added to Wishlist',
          product_removed_from_wishlist: 'Product Removed from Wishlist',

          subscribed_to_newsletter: 'Subscribed to Newsletter',
          unsubscribed_from_newsletter: 'Unsubscribed from Newsletter',

          payment_info_entered: 'Payment Info Entered',
          coupon_entered: 'Coupon Entered',
          coupon_removed: 'Coupon Removed',
          coupon_applied: 'Coupon Applied',
          coupon_denied: 'Coupon Denied',

          checkout_started: 'Checkout Started',
          checkout_email_entered: 'Checkout Email Entered',
          checkout_step_viewed: 'Checkout Step Viewed',
          checkout_step_completed: 'Checkout Step Completed',
          order_completed: 'Order Completed',
        }
        Rails.application.config.spree.analytics_event_handlers = []

        Rails.application.config.spree.integrations = []

        Rails.application.config.spree.validators.addresses = [
          Spree::Addresses::PhoneValidator
        ]

        # Add core event subscribers
        # Other engines add their subscribers in their own after_initialize blocks
        # Note: Spree::EventLogSubscriber is attached in to_prepare (below) so it
        # survives Zeitwerk code reloads in development.
        Spree.subscribers.concat [
          Spree::OrderPlacedSubscriber,
          Spree::OrderCommissionSubscriber,
          Spree::OrderStatusSubscriber,
          Spree::PaymentSplitSubscriber,
          Spree::ExportSubscriber,
          Spree::ReportSubscriber,
          Spree::InvitationEmailSubscriber,
          Spree::SellerOnboardingSubscriber,
          Spree::AdminUserEmailSubscriber,
          Spree::SellerUserEmailSubscriber,
          Spree::ProductMetricsSubscriber,
          Spree::TaxIdentifierValidationSubscriber
        ]

        # Pre-load authentication strategy classes to avoid reflection at request time
        Rails.application.config.spree.store_authentication_strategies = Spree::Authentication::StrategyRegistry.new(
          email: Spree::Authentication::Strategies::EmailPasswordStrategy
        )
        Rails.application.config.spree.admin_authentication_strategies = Spree::Authentication::StrategyRegistry.new(
          email: Spree::Authentication::Strategies::EmailPasswordStrategy
        )
        Rails.application.config.spree.seller_authentication_strategies = Spree::Authentication::StrategyRegistry.new(
          email: Spree::Authentication::Strategies::EmailPasswordStrategy
        )
      end

      initializer 'spree.promo.register.promotions.actions' do |app|
      end

      # filter sensitive information during logging
      initializer 'spree.params.filter' do |app|
        app.config.filter_parameters += [
          :password,
          :password_confirmation,
          :number,
          :verification_value,
          :client_id,
          :client_secret,
          :refresh_token
        ]
      end

      initializer 'spree.core.checking_migrations' do |app|
        app.config.after_initialize do
          Migrations.new(config, engine_name).check unless Rails.env.test? || Spree::Config.disable_migration_check
        end
      end

      # Activate event subscribers after all engines have registered their subscribers
      # This registers an after_initialize callback late, ensuring it runs after all engine callbacks
      # Needed for console, jobs, and other contexts where to_prepare doesn't run
      initializer 'spree.events.schedule_activation', after: :load_config_initializers do |app|
        app.config.after_initialize do
          Spree::Events.activate!
        end
      end

      # The one eligibility rule core ships: a per-market return window,
      # bypassed by staff. Registered after application initializers so a
      # store can unregister it in its own initializer.
      initializer 'spree.returns.register_eligibility_validator', after: :load_config_initializers do
        Spree.hooks.register('returns.create.validate', 'Spree::Returns::EligibilityValidator')
        Spree.hooks.register('exchanges.create.validate', 'Spree::Returns::EligibilityValidator')
      end

      # A hook registered against a key no workflow declares would never fire
      # and never say so. Checking after eager load turns that typo into a
      # boot failure. Skipped when eager loading is off (development,
      # console): workflow classes load lazily there, so a declared hook may
      # simply not be defined yet.
      initializer 'spree.hooks.validate', after: :load_config_initializers do |app|
        app.config.after_initialize do
          Spree.hooks.validate! if app.config.eager_load
        end
      end

      config.to_prepare do
        # Ensure spree locale paths are present before decorators
        I18n.load_path.unshift(*(Dir.glob(
          File.join(
            File.dirname(__FILE__), '../../../config/locales', '*.{rb,yml}'
          )
        ) - I18n.load_path))

        # Load application's model / class decorators
        Dir.glob(File.join(File.dirname(__FILE__), '../../../app/**/*_decorator*.rb')) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end

        # Reset and re-activate event subscribers on code reload
        # activate! will register all subscribers from Spree.subscribers
        # Note: resolve_subscriber in register_subscribers! handles stale class references
        Spree::Events.reset!
        Spree::Events.activate!

        # Re-attach event log subscriber if enabled
        if Spree::Config.events_log_enabled
          Spree::EventLogSubscriber.attach_to_notifications
        end
      end
    end
  end
end

require 'spree/core/routes'
