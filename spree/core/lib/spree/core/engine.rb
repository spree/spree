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
                               :default_payout_provider,
                               :payout_providers,
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
                               :actor_classes,
                               :custom_fields,
                               :reporting,
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
        app.config.spree = Environment.new(SpreeCalculators.new([], [], [], []), SpreeValidators.new, Spree::Core::Configuration.new, Spree::Core::Dependencies.new)

        # Every registry core fills in after_initialize exists, empty, before
        # any initializer file runs, so an application or extension can
        # register from a plain initializer. Core's defaults are put in front
        # of those entries later (see .register_defaults).
        %i[payment_methods adjusters media_viewable_types fulfillment_providers stock_splitters
           data_feed_types export_types import_types taxon_rules collection_rules
           time_based_collection_rules translatable_resources taggable_types
           analytics_event_handlers integrations].each { |registry| app.config.spree[registry] = [] }
        app.config.spree.tracking_carriers = {}
        app.config.spree.analytics_events = {}
        app.config.spree.store_authentication_strategies = Spree::Authentication::StrategyRegistry.new
        app.config.spree.admin_authentication_strategies = Spree::Authentication::StrategyRegistry.new
        app.config.spree.seller_authentication_strategies = Spree::Authentication::StrategyRegistry.new

        app.config.active_record.yaml_column_permitted_classes ||= []
        app.config.active_record.yaml_column_permitted_classes.concat([Symbol, BigDecimal, ActiveSupport::HashWithIndifferentAccess, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Time])
        Spree::Config = app.config.spree.preferences
        Spree::RuntimeConfig = app.config.spree.preferences # for compatibility
        Spree::Dependencies = app.config.spree.dependencies
        Spree::Deprecation = ActiveSupport::Deprecation.new('6.0', 'Spree')
      end

      # Runs after initializers so an explicitly assigned preference — which
      # wins over the environment — is never rejected for a stale env var.
      config.after_initialize do
        Spree::Core::Configuration.validate_env!(Spree::Config)
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

      # Seeded before application initializers so an extension registering an
      # actor class has something to append to. The defaults are added after
      # initialization, where Spree.admin_user_class is finally known.
      initializer 'spree.register.actor_classes', before: :load_config_initializers do |app|
        app.config.spree.actor_classes = []
      end

      # Seeded before application initializers so a host's
      # `config/initializers/spree.rb` can register custom generators.
      initializer 'spree.register.number_generators', before: :load_config_initializers do |app|
        app.config.spree.number_generators = Spree::NumberGenerators::Registry.new
      end

      initializer 'spree.register.line_item_comparison_hooks', before: :load_config_initializers do |app|
        app.config.spree.line_item_comparison_hooks = Set.new
      end

      # The one eligibility rule core ships: a per-market return window,
      # bypassed by staff. Registered before application initializers so a
      # store can unregister it in its own initializer.
      initializer 'spree.returns.register_eligibility_validator', before: :load_config_initializers do
        Spree.hooks.register('returns.create.validate', 'Spree::Returns::EligibilityValidator')
        Spree.hooks.register('exchanges.create.validate', 'Spree::Returns::EligibilityValidator')
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

      # How sellers get paid. A provider gem — the Stripe Connect one, or a
      # marketplace's own — registers from an initializer file; core's
      # record-only System concatenates below.
      initializer 'spree.register.payout_providers', before: :load_config_initializers do |app|
        app.config.spree.payout_providers = []
      end

      initializer 'spree.register.digital_asset_providers', before: :load_config_initializers do |app|
        app.config.spree.digital_asset_providers = []
      end

      initializer 'spree.register.delivery_profile_types', before: :load_config_initializers do |app|
        app.config.spree.delivery_profile_types = []
      end

      initializer 'spree.register.custom_fields', before: :load_config_initializers do |app|
        app.config.spree.custom_fields = CustomFieldsEnvironment.new
        app.config.spree.custom_fields.types = []
        app.config.spree.custom_fields.enabled_resources = []
      end

      # Seed the reporting vocabulary before app initializers so applications
      # and extensions can register their own metrics/dimensions in
      # config/initializers (see docs/plans/6.0-analytics-semantic-layer.md).
      initializer 'spree.register.reporting', before: :load_config_initializers do |app|
        app.config.spree.reporting = Spree::Reporting::Registry.new
        Spree::Reporting::DefaultVocabulary.install(app.config.spree.reporting)
      end

      # We need to define promotions rules here so extensions and existing apps
      # can add their custom classes on their initializer files
      initializer 'spree.promo.environment', before: :load_config_initializers do |app|
        app.config.spree.promotions = PromoEnvironment.new([], [])
      end

      # Pricing configuration for price lists and price rules
      initializer 'spree.pricing.environment', after: 'spree.environment', before: :load_config_initializers do |app|
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

      # Core's defaults are registered after initialization: some name
      # Spree.customer_class, which the application only sets in its own
      # initializer, and loading model classes any earlier would break their
      # associations. Registries are seeded empty before initializer files run
      # (see 'spree.environment'), so what an application or extension
      # registered there, or registers in a later after_initialize, is kept.
      config.after_initialize do
        register_defaults Rails.application.config.spree.calculators.shipping_methods, [
          Spree::Calculator::Shipping::FlatPercentItemTotal,
          Spree::Calculator::Shipping::FlatRate,
          Spree::Calculator::Shipping::FlexiRate,
          Spree::Calculator::Shipping::PerItem,
          Spree::Calculator::Shipping::PriceSack,
          Spree::Calculator::Shipping::DigitalDelivery,
        ]

        register_defaults Rails.application.config.spree.stock_splitters, [
          Spree::Stock::Splitter::DeliveryProfile,
          Spree::Stock::Splitter::Backordered
        ]

        register_defaults Rails.application.config.spree.payment_methods, [
          Spree::Gateway::Bogus,
          Spree::Gateway::CustomPaymentSourceMethod,
          Spree::PaymentMethod::Check,
          Spree::PaymentMethod::StoreCredit
        ]

        register_defaults Rails.application.config.spree.adjusters, [
          Spree::Adjusters::Promotion
        ]

        # What a media file can be placed on. The polymorphic viewable column
        # would otherwise accept any constant name, and everything downstream —
        # store resolution, counter caches, the usage panel — reasons about the
        # registered set. An extension placing media on its own model appends
        # to this from an initializer.
        register_defaults Rails.application.config.spree.media_viewable_types, %w[
          Spree::Product
          Spree::Variant
          Spree::Category
          Spree::Collection
        ]


        # The fallback engine when a market names none (see docs/plans/6.0-tax-provider.md).
        # Assigned only if an initializer file has not already named one — an app
        # that picks its own default must keep it.
        Rails.application.config.spree.default_tax_provider ||= Spree::TaxProvider::Internal

        # Engines a market can select. Provider gems and host apps append theirs.
        register_defaults Rails.application.config.spree.tax_providers, [Spree::TaxProvider::Internal]

        # Pricing and inventory sources. Internal is Spree's own catalog and
        # stock records; connector gems append theirs so a merchant picks from
        # what is installed (see docs/plans/6.0-third-party-pricing-inventory.md).
        register_defaults Rails.application.config.spree.pricing_providers, [Spree::PricingProvider::Internal]
        register_defaults Rails.application.config.spree.inventory_providers, [Spree::InventoryProvider::Internal]
        # 'manual' is the negotiated-price marker on line items, so no pricing
        # engine may answer under it — fail the boot rather than the checkout.
        Spree::PricingProvider.verify_registry!

        # How sellers are paid when a store names nothing: the books are kept
        # and the operator settles offline. Assigned only if an initializer has
        # not already chosen one.
        Rails.application.config.spree.default_payout_provider ||= Spree::PayoutProvider::System
        register_defaults Rails.application.config.spree.payout_providers, [Spree::PayoutProvider::System]

        # Password policy for the default auth models. Swap for corporate rules,
        # breach-list lookups or entropy scoring.
        Rails.application.config.spree.password_validator ||= Spree::PasswordLengthValidator

        register_defaults Rails.application.config.spree.fulfillment_providers, [
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
        register_defaults Rails.application.config.spree.tracking_carriers, {
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
        register_defaults Rails.application.config.spree.delivery_rate_providers, [
          Spree::DeliveryRateProvider::Internal,
          Spree::DeliveryRateProvider::Freight
        ]

        # Digital asset sources. Core ships the uploaded-file default; host
        # apps append providers that resolve a deliverable elsewhere.
        register_defaults Rails.application.config.spree.digital_asset_providers, [
          Spree::DigitalAssetProvider::File
        ]

        # Profile kinds selectable when creating a delivery profile;
        # extension kinds append theirs.
        register_defaults Rails.application.config.spree.delivery_profile_types, [
          Spree::DeliveryProfiles::Shipping,
          Spree::DeliveryProfiles::Digital
        ]

        # Selectable order routing strategies. The internal Reducer collaborator
        # is intentionally NOT listed — it is not a Strategy::Base. Plugins add
        # their own via this array.
        register_defaults Rails.application.config.spree.order_routing.strategies, [
          Spree::OrderRouting::Strategy::Rules
        ]

        # Available order routing rule kinds. STI dispatches at runtime via the
        # +type+ column; this array is the curated allowlist that drives admin
        # pickers and the rule +type+ validation. Plugins append their own.
        register_defaults Rails.application.config.spree.order_routing.rules, [
          Spree::OrderRouting::Rules::PreferredLocation,
          Spree::OrderRouting::Rules::MinimizeSplits,
          Spree::OrderRouting::Rules::DefaultLocation
        ]

        # Commission targeting rule kinds (docs/plans/6.0-multi-vendor-marketplace.md).
        register_defaults Rails.application.config.spree.commission_rules, [
          Spree::CommissionRules::SellerRule,
          Spree::CommissionRules::CategoryRule,
          Spree::CommissionRules::ProductRule,
          Spree::CommissionRules::ItemTotalRule
        ]

        # Seller onboarding requirement kinds
        # (docs/plans/6.0-seller-onboarding-requirements.md).
        register_defaults Rails.application.config.spree.seller_requirements, [
          Spree::SellerRequirements::AcceptTerms,
          Spree::SellerRequirements::CompleteProfile,
          Spree::SellerRequirements::BillingAddress,
          Spree::SellerRequirements::ReturnsAddress,
          Spree::SellerRequirements::DeliveryMethod,
          Spree::SellerRequirements::PackageType,
          Spree::SellerRequirements::MinimumProducts,
          Spree::SellerRequirements::PayoutAccount,
          Spree::SellerRequirements::RequiredCustomFields,
          Spree::SellerRequirements::Policy,
          Spree::SellerRequirements::Attestation,
          Spree::SellerRequirements::OperatorReview,
          Spree::SellerRequirements::Document
        ]

        # Delivery-method eligibility rule kinds (docs/plans/6.0-delivery-method-rules.md).
        register_defaults Rails.application.config.spree.delivery_method_rules, [
          Spree::DeliveryMethodRules::ItemTotalRule,
          Spree::DeliveryMethodRules::WeightRule,
          Spree::DeliveryMethodRules::ExcludedProductsRule,
          Spree::DeliveryMethodRules::ChannelRule,
          Spree::DeliveryMethodRules::VolumeRule,
          Spree::DeliveryMethodRules::CompanyRule
        ]

        register_defaults Rails.application.config.spree.calculators.promotion_actions_create_adjustments, [
          Spree::Calculator::FlatPercentItemTotal,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate,
          Spree::Calculator::TieredPercent,
          Spree::Calculator::TieredFlatRate
        ]

        register_defaults Rails.application.config.spree.calculators.promotion_actions_create_item_adjustments, [
          Spree::Calculator::PercentOnLineItem,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate
        ]

        register_defaults Rails.application.config.spree.promotions.rules, [
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
        register_defaults Rails.application.config.spree.pricing.rules, [
          Spree::PriceRules::UserRule,
          Spree::PriceRules::CustomerGroupRule,
          Spree::PriceRules::VolumeRule,
          Spree::PriceRules::MarketRule,
          Spree::PriceRules::ChannelRule
        ]

        register_defaults Rails.application.config.spree.promotions.actions, [
          Promotion::Actions::CreateAdjustment,
          Promotion::Actions::CreateItemAdjustments,
          Promotion::Actions::CreateLineItems,
          Promotion::Actions::FreeShipping
        ]

        register_defaults Rails.application.config.spree.data_feed_types, [
          Spree::DataFeed::Google
        ]

        register_defaults Rails.application.config.spree.export_types, [
          Spree::Exports::Products,
          Spree::Exports::ProductTranslations,
          Spree::Exports::Orders,
          Spree::Exports::Customers,
          Spree::Exports::GiftCards,
          Spree::Exports::NewsletterSubscribers,
          Spree::Exports::CouponCodes,
          Spree::Exports::PriceListPrices,
          Spree::Exports::PurchaseOrders,
          Spree::Exports::Report
        ]

        register_defaults Rails.application.config.spree.import_types, [
          Spree::Imports::Products,
          Spree::Imports::ProductTranslations,
          Spree::Imports::Customers,
          Spree::Imports::PriceListPrices,
          Spree::Imports::PurchaseOrders
        ]

        register_defaults Rails.application.config.spree.taxon_rules, [
          Spree::TaxonRules::Tag,
          Spree::TaxonRules::AvailableOn,
          Spree::TaxonRules::Sale,
        ]

        # Mirrors config.spree.taxon_rules above. AvailableOn ships with an interim
        # legacy-column implementation; its channel-aware rewrite is a later phase
        # (see docs/plans/6.0-replace-taxons-with-categories.md → Migration Phase 5).
        register_defaults Rails.application.config.spree.collection_rules, [
          Spree::CollectionRules::Tag,
          Spree::CollectionRules::AvailableOn,
          Spree::CollectionRules::Sale,
        ]

        # Net-new (no taxon_rules equivalent — taxons ship no scheduled refresh).
        # Drives Spree::Collections::RegenerateTimeBasedJob.
        register_defaults Rails.application.config.spree.time_based_collection_rules, [
          Spree::CollectionRules::AvailableOn,
        ]

        register_defaults Rails.application.config.spree.translatable_resources, [
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
        # Extend in an app initializer to surface custom taggables — e.g.
        #   Rails.application.config.spree.taggable_types << 'MyApp::Seller'.
        register_defaults Rails.application.config.spree.taggable_types, [
          'Spree::Product',
          'Spree::Order',
          Spree.customer_class.to_s
        ]

        # Models that may be recorded as having performed an action — the
        # vocabulary an `acted_by` association's `*_type` column is validated
        # against. Extend in an app initializer to register an App or bot
        # class, which must include Spree::Actor:
        #   Rails.application.config.spree.actor_classes << 'MyApp::App'.
        register_defaults Rails.application.config.spree.actor_classes, [
          Spree.admin_user_class.to_s,
          'Spree::ApiKey'
        ]

        register_defaults Rails.application.config.spree.custom_fields.types, [
          Spree::CustomFields::ShortText,
          Spree::CustomFields::LongText,
          Spree::CustomFields::RichText,
          Spree::CustomFields::Number,
          Spree::CustomFields::Boolean,
          Spree::CustomFields::Json
        ]

        register_defaults Rails.application.config.spree.custom_fields.enabled_resources, [
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

        register_defaults Rails.application.config.spree.analytics_events, {
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

        Rails.application.config.spree.validators.addresses.register_defaults [
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
          Spree::SellerTransferSubscriber,
          Spree::SellerTransferReversalSubscriber,
          Spree::ExportSubscriber,
          Spree::InvitationEmailSubscriber,
          Spree::SellerOnboardingSubscriber,
          Spree::AdminUserEmailSubscriber,
          Spree::SellerUserEmailSubscriber,
          Spree::ProductMetricsSubscriber,
          Spree::TaxIdentifierValidationSubscriber
        ]

        # Pre-load authentication strategy classes to avoid reflection at request time
        Rails.application.config.spree.store_authentication_strategies.register_defaults(
          email: Spree::Authentication::Strategies::EmailPasswordStrategy
        )
        Rails.application.config.spree.admin_authentication_strategies.register_defaults(
          email: Spree::Authentication::Strategies::EmailPasswordStrategy
        )
        Rails.application.config.spree.seller_authentication_strategies.register_defaults(
          email: Spree::Authentication::Strategies::EmailPasswordStrategy
        )
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

      # Puts core's defaults ahead of whatever was registered before them,
      # keeping each entry once. A Hash keeps the value registered under a
      # default's key, so an application can override a single default.
      #
      # @param registry [Array, Hash] the registry to fill, changed in place
      # @param defaults [Array, Hash] core's entries, in their canonical order
      # @return [Array, Hash] the registry
      def self.register_defaults(registry, defaults)
        registry.replace(registry.is_a?(Hash) ? defaults.merge(registry) : defaults | registry)
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

        # Same stale-class problem as the subscribers above, for the provider
        # registries the admin catalogs iterate.
        Spree.refresh_provider_registries!

        # Re-attach event log subscriber if enabled
        if Spree::Config.events_log_enabled
          Spree::EventLogSubscriber.attach_to_notifications
        end
      end
    end
  end
end

require 'spree/core/routes'
