require 'ostruct'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_job/railtie'
require 'active_model/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'pagy'

require 'mail'
require 'action_mailer/railtie'


require 'acts_as_list'
require 'acts-as-taggable-on'
require 'awesome_nested_set'
require 'cancan'
require 'countries/global'
require 'friendly_id'
require 'jwt'
require 'monetize'
require 'mobility'
require 'name_of_person'
require 'nokogiri'
require 'rails-html-sanitizer'
require 'paranoia'
require 'request_store'
require 'ransack'
require 'active_storage_validations'
require 'wannabe_bool'
require 'geocoder'

require 'safely_block'
require 'ar_lazy_preload'
require 'sqids'

module Spree
  mattr_accessor :base_class, :customer_class, :admin_user_class,
                 :private_storage_service_name, :public_storage_service_name,
                 :cdn_host, :root_domain, :events_adapter_class, :queues,
                 :google_places_api_key

  # Whether the connected database is MySQL or a MySQL-compatible server.
  # The single definition every adapter branch reads — models, services and
  # migrations alike — so a new adapter name is added in one place.
  #
  # Matches Trilogy and MariaDB as well as Mysql2: they share the behaviors
  # Spree branches on (no partial indexes, `upsert_all` inferring its own
  # conflict target, NULLs distinct in unique indexes).
  #
  # @return [Boolean]
  def self.mysql?
    ActiveRecord::Base.connection.adapter_name.match?(/mysql|trilogy/i)
  end

  def self.base_class(constantize: true)
    @@base_class ||= 'Spree::Base'
    if @@base_class.is_a?(Class)
      raise 'Spree.base_class MUST be a String or Symbol object, not a Class object.'
    elsif @@base_class.is_a?(String) || @@base_class.is_a?(Symbol)
      constantize ? @@base_class.to_s.constantize : @@base_class.to_s
    end
  end

  def self.customer_class(constantize: true)
    if @@customer_class.is_a?(Class)
      raise 'Spree.customer_class MUST be a String or Symbol object, not a Class object.'
    elsif @@customer_class.is_a?(String) || @@customer_class.is_a?(Symbol)
      constantize ? @@customer_class.to_s.constantize : @@customer_class.to_s
    end
  end

  # @deprecated Spree.user_class was renamed to Spree.customer_class in 6.0; removed in 6.1.
  def self.user_class(constantize: true)
    Spree::Deprecation.warn('Spree.user_class is deprecated and will be removed in Spree 6.1. Use Spree.customer_class instead.') if defined?(Spree::Deprecation)
    customer_class(constantize: constantize)
  end

  # @deprecated Spree.user_class= was renamed to Spree.customer_class= in 6.0; removed in 6.1.
  def self.user_class=(value)
    Spree::Deprecation.warn('Spree.user_class= is deprecated and will be removed in Spree 6.1. Use Spree.customer_class= instead.') if defined?(Spree::Deprecation)
    self.customer_class = value
  end

  def self.admin_user_class(constantize: true)
    if @@admin_user_class.is_a?(Class)
      raise 'Spree.admin_user_class MUST be a String or Symbol object, not a Class object.'
    elsif @@admin_user_class.is_a?(String) || @@admin_user_class.is_a?(Symbol)
      constantize ? @@admin_user_class.to_s.constantize : @@admin_user_class.to_s
    end
  end

  def self.private_storage_service_name
    if @@private_storage_service_name
      if @@private_storage_service_name.is_a?(String) || @@private_storage_service_name.is_a?(Symbol)
        @@private_storage_service_name.to_sym
      end
    else
      Rails.application.config.active_storage.service
    end
  end

  def self.public_storage_service_name
    if @@public_storage_service_name
      if @@public_storage_service_name.is_a?(String) || @@public_storage_service_name.is_a?(Symbol)
        @@public_storage_service_name.to_sym
      end
    else
      Rails.application.config.active_storage.service
    end
  end

  def self.root_domain
    @@root_domain
  end

  def self.queues
    @@queues ||= OpenStruct.new(
      default: :default,
      events: :default,
      exports: :default,
      images: :default,
      imports: :default,
      products: :default,
      reports: :default,
      variants: :default,
      categories: :default,
      collections: :default,
      stock_location_stock_levels: :default,
      coupon_codes: :default,
      themes: :default,
      addresses: :default,
      gift_cards: :default,
      webhooks: :default,
      payment_webhooks: :default,
      api_keys: :default,
      search: :default,
      stock_reservations: :default,
      tax_identifiers: :default,
      payouts: :default
    ).tap do |queues|
      # @deprecated The taxons queue was renamed to categories in 6.0; removed in 6.1.
      queues.define_singleton_method(:taxons) do
        Spree::Deprecation.warn('Spree.queues.taxons is deprecated and will be removed in Spree 6.1. Use Spree.queues.categories instead.') if defined?(Spree::Deprecation)
        categories
      end

      # @deprecated Renamed with the stock level rename in 6.0; removed in 6.1.
      #
      # The writer matters as much as the reader here: this is an OpenStruct, so
      # an existing initializer assigning the old name would quietly define a
      # field nobody reads and its jobs would fall back to the default queue.
      queues.define_singleton_method(:stock_location_stock_items) do
        Spree::Deprecation.warn('Spree.queues.stock_location_stock_items is deprecated and will be removed in Spree 6.1. Use Spree.queues.stock_location_stock_levels instead.') if defined?(Spree::Deprecation)
        stock_location_stock_levels
      end

      queues.define_singleton_method(:stock_location_stock_items=) do |value|
        Spree::Deprecation.warn('Spree.queues.stock_location_stock_items= is deprecated and will be removed in Spree 6.1. Use Spree.queues.stock_location_stock_levels= instead.') if defined?(Spree::Deprecation)
        self.stock_location_stock_levels = value
      end
    end
  end

  # Search provider class name. Controls product search, filtering, and faceted navigation.
  #
  #   Spree.search_provider = 'SpreeMeilisearch::SearchProvider'
  #
  def self.search_provider
    @@search_provider ||= 'Spree::SearchProvider::Database'
  end

  def self.search_provider=(value)
    @@search_provider = value.to_s
  end

  # Tax ID validators, keyed by registration kind.
  #
  # Core ships one, for +eu_vat+, and it checks format only — the shape of an EU
  # VAT number is arithmetic, so it costs nothing and needs no credentials.
  # Core ships **no registry client** for any jurisdiction: asking whether a
  # number is actually registered means a network call to somebody's government,
  # and that belongs to the extension that wants it.
  #
  #   # Take over both halves of eu_vat, format and registry alike.
  #   Spree.tax_identifier_validators['eu_vat'] = 'SpreeEuVat::TaxIdentifierValidator'
  #
  #   # Or cover a kind nothing here knows about.
  #   Spree.tax_identifier_validators['au_abn'] = 'SpreeAuAbn::TaxIdentifierValidator'
  #
  # Class names are stored as strings and constantized at call time, so an
  # initializer can register a validator before its class is autoloaded.
  # Whether a kind has a validator is also what tells the admin apart the two
  # reasons a registration has no verdict: unchecked, or uncheckable here.
  #
  # @return [Hash{String => String}]
  def self.tax_identifier_validators
    @@tax_identifier_validators ||= { 'eu_vat' => 'Spree::TaxIdentifiers::Validator::EuVat' }
  end

  # Returns the events adapter class used for publishing and subscribing to events.
  #
  # @example Using a custom adapter
  #   Spree.events_adapter_class = 'MyApp::Events::KafkaAdapter'
  #
  # @param constantize [Boolean] whether to return the class or the string
  # @return [Class, String] the adapter class or its name
  def self.events_adapter_class(constantize: true)
    @@events_adapter_class ||= 'Spree::Events::Adapters::ActiveSupportNotifications'

    if @@events_adapter_class.is_a?(Class)
      raise 'Spree.events_adapter_class MUST be a String or Symbol object, not a Class object.'
    elsif @@events_adapter_class.is_a?(String) || @@events_adapter_class.is_a?(Symbol)
      constantize ? @@events_adapter_class.to_s.constantize : @@events_adapter_class.to_s
    end
  end

  def self.google_places_api_key
    @@google_places_api_key
  end

  def self.always_use_translations?
    Spree::Config.always_use_translations
  end

  def self.use_translations?
    Spree::Config.always_use_translations || Spree::Current.content_locale != I18n.locale.name
  end

  # Mobility +column_fallback+ option shared by every translatable model:
  # read, write and query the base (untranslated) column when the target
  # locale is the request's content locale — see Spree::Current#content_locale.
  # Evaluated on every translated attribute read, so it must stay
  # allocation-free and must not touch the database (Symbol#name returns the
  # frozen interned string; Mobility always passes Symbol locales).
  def self.mobility_column_fallback
    return false if always_use_translations?

    ->(locale) { locale.name == Spree::Current.content_locale }
  end

  # Stable anonymous identifier for this Spree installation. Generated once,
  # persisted in the preferences store and reused afterwards. It identifies the
  # installation only
  #
  # Deliberately not memoized: the persisted preference is the single source
  # of truth, so processes that race to generate the first value converge on
  # the winning row at the next read instead of each holding a different id
  # for their lifetime.
  #
  # @return [String] UUID
  def self.install_id
    store = Spree::Preferences::Store.instance
    store.get('spree/install_id') { nil }.presence ||
      SecureRandom.uuid.tap { |id| store.set('spree/install_id', id) }
  end

  # Used to configure Spree.
  #
  # Example:
  #
  #   Spree.config do |config|
  #     config.track_inventory_levels = false
  #   end
  #
  # This method is defined within the core gem on purpose.
  # Some people may only wish to use the Core part of Spree.
  def self.config
    Rails.application.config.after_initialize do
      yield(Spree::Config)
    end
  end

  # Used to set dependencies for Spree.
  #
  # Example:
  #
  #   Spree.dependencies do |dependency|
  #     dependency.cart_add_item_service = MyCustomAddToCart
  #   end
  #
  # This method is defined within the core gem on purpose.
  # Some people may only wish to use the Core part of Spree.
  def self.dependencies
    yield(Spree::Dependencies)
  end

  # Environment accessors for easier configuration access
  # Instead of Rails.application.config.spree.payment_methods
  # you can use Spree.payment_methods

  def self.calculators
    Rails.application.config.spree.calculators
  end

  def self.calculators=(value)
    Rails.application.config.spree.calculators = value
  end

  def self.validators
    Rails.application.config.spree.validators
  end

  def self.validators=(value)
    Rails.application.config.spree.validators = value
  end

  def self.payment_methods
    Rails.application.config.spree.payment_methods
  end

  def self.payment_methods=(value)
    Rails.application.config.spree.payment_methods = value
  end

  def self.adjusters
    Rails.application.config.spree.adjusters
  end

  def self.adjusters=(value)
    Rails.application.config.spree.adjusters = value
  end

  # Model names a {Spree::Media} row may be placed on — where a file *lives*.
  # The viewable column is polymorphic, so this is what keeps it from accepting
  # any constant, and what store resolution, counter caches and the usage panel
  # reason about.
  #
  # Append, never assign, so an extension does not drop what another added:
  #
  #   Spree.media_viewable_types += ['MyApp::Lookbook']
  #
  # @return [Array<String>]
  def self.media_viewable_types
    Rails.application.config.spree.media_viewable_types
  end

  def self.media_viewable_types=(value)
    Rails.application.config.spree.media_viewable_types = value
  end

  # The tax engine used when a market names none — the fallback behind
  # {Spree::Purchase::Taxation#tax_provider}, which is what call sites actually
  # use. Defaults to {Spree::TaxProvider::Internal}.
  #
  #   Spree.default_tax_provider = SpreeTaxAvalara::TaxProvider
  #
  # Returns the class rather than an instance: callers that want one say `.new`,
  # and the ones that only need to name it (market selection constantizing its
  # own choice, the admin marking which entry is the default) do not pay for an
  # object they discard. A String or Symbol is accepted and constantized, so an
  # initializer can name a provider before its class is autoloaded.
  #
  # @return [Class]
  def self.default_tax_provider
    provider = Rails.application.config.spree.default_tax_provider
    provider.is_a?(Class) ? provider : provider.to_s.constantize
  end

  def self.default_tax_provider=(value)
    Rails.application.config.spree.default_tax_provider = value
  end

  # Tax engines a market can be pointed at. Provider gems append their own, so a
  # merchant picks from what is actually installed rather than typing a class
  # name and finding out at checkout.
  #
  # @return [Array<Class>]
  def self.tax_providers
    Rails.application.config.spree.tax_providers
  end

  def self.tax_providers=(value)
    Rails.application.config.spree.tax_providers = value
  end

  # Pricing engines a store can be pointed at. Connector gems append their own,
  # so a merchant picks from what is actually installed.
  #
  # @return [Array<Class>]
  def self.pricing_providers
    Rails.application.config.spree.pricing_providers
  end

  def self.pricing_providers=(value)
    Rails.application.config.spree.pricing_providers = value
  end

  # Inventory sources a store can be pointed at.
  #
  # @return [Array<Class>]
  def self.inventory_providers
    Rails.application.config.spree.inventory_providers
  end

  def self.inventory_providers=(value)
    Rails.application.config.spree.inventory_providers = value
  end

  # How sellers get paid. Core ships {Spree::PayoutProvider::System}, which
  # keeps the books and leaves the operator to settle; a provider gem appends
  # one that moves the money itself.
  #
  # @return [Array<Class>]
  def self.payout_providers
    Rails.application.config.spree.payout_providers
  end

  def self.payout_providers=(value)
    Rails.application.config.spree.payout_providers = value
  end

  # The provider a store pays through when it has named none.
  #
  # @return [Class]
  def self.default_payout_provider
    Rails.application.config.spree.default_payout_provider
  end

  def self.default_payout_provider=(value)
    Rails.application.config.spree.default_payout_provider = value
  end

  # Validator enforcing the password policy on the default auth models
  # ({Spree::Customer}, {Spree::AdminUser}). Defaults to
  # {Spree::PasswordLengthValidator}, which reads the configurable length bounds.
  #
  # Assign an +ActiveModel::Validator+ subclass to replace the policy wholesale —
  # corporate rules, breach-list lookups, entropy scoring. Errors it adds to
  # +:password+ reach API clients through the standard 422 path, so the
  # validator's message is the user-facing reason.
  #
  #   Spree.password_validator = MyApp::PasswordValidator
  #
  # @return [Class]
  def self.password_validator
    Rails.application.config.spree.password_validator
  end

  def self.password_validator=(value)
    Rails.application.config.spree.password_validator = value
  end

  def self.fulfillment_providers
    Rails.application.config.spree.fulfillment_providers
  end

  def self.fulfillment_providers=(value)
    Rails.application.config.spree.fulfillment_providers = value
  end

  def self.tracking_carriers
    Rails.application.config.spree.tracking_carriers
  end

  def self.tracking_carriers=(value)
    Rails.application.config.spree.tracking_carriers = value
  end


  def self.stock_splitters
    Rails.application.config.spree.stock_splitters
  end

  def self.stock_splitters=(value)
    Rails.application.config.spree.stock_splitters = value
  end

  # Commission rule kinds selectable on a commission rate.
  #
  # @return [Array<Class>]
  def self.commission_rules
    Rails.application.config.spree.commission_rules
  end

  def self.commission_rules=(value)
    Rails.application.config.spree.commission_rules = value
  end

  # Seller onboarding requirement kinds an operator can configure
  # (docs/plans/6.0-seller-onboarding-requirements.md).
  #
  # @return [Array<Class>]
  def self.seller_requirements
    Rails.application.config.spree.seller_requirements
  end

  def self.seller_requirements=(value)
    Rails.application.config.spree.seller_requirements = value
  end

  def self.delivery_method_rules
    Rails.application.config.spree.delivery_method_rules
  end

  def self.delivery_method_rules=(value)
    Rails.application.config.spree.delivery_method_rules = value
  end

  # Quoting strategies selectable on a delivery method.
  #
  # @return [Array<Class>]
  def self.delivery_rate_providers
    Rails.application.config.spree.delivery_rate_providers
  end

  def self.delivery_rate_providers=(value)
    Rails.application.config.spree.delivery_rate_providers = value
  end

  # Strategies selectable as a digital asset's source. Core registers the
  # uploaded-file default; host apps append providers that resolve a
  # deliverable elsewhere (a licensing system, a code pool).
  #
  # @return [Array<Class>]
  def self.digital_asset_providers
    Rails.application.config.spree.digital_asset_providers
  end

  def self.digital_asset_providers=(value)
    Rails.application.config.spree.digital_asset_providers = value
  end

  # Fulfillment profile kinds selectable when creating a profile.
  #
  # @return [Array<Class>]
  def self.delivery_profile_types
    Rails.application.config.spree.delivery_profile_types
  end

  def self.delivery_profile_types=(value)
    Rails.application.config.spree.delivery_profile_types = value
  end

  def self.order_routing
    Rails.application.config.spree.order_routing
  end

  def self.order_routing=(value)
    Rails.application.config.spree.order_routing = value
  end

  def self.promotions
    Rails.application.config.spree.promotions
  end

  def self.promotions=(value)
    Rails.application.config.spree.promotions = value
  end

  def self.line_item_comparison_hooks
    Rails.application.config.spree.line_item_comparison_hooks
  end

  def self.line_item_comparison_hooks=(value)
    Rails.application.config.spree.line_item_comparison_hooks = value
  end

  def self.data_feed_types
    Rails.application.config.spree.data_feed_types
  end

  def self.data_feed_types=(value)
    Rails.application.config.spree.data_feed_types = value
  end

  def self.export_types
    Rails.application.config.spree.export_types
  end

  def self.export_types=(value)
    Rails.application.config.spree.export_types = value
  end

  def self.import_types
    Rails.application.config.spree.import_types
  end

  def self.import_types=(value)
    Rails.application.config.spree.import_types = value
  end

  def self.taxon_rules
    Rails.application.config.spree.taxon_rules
  end

  def self.taxon_rules=(value)
    Rails.application.config.spree.taxon_rules = value
  end

  # Class-name strings (`'Spree::Product'`, `'Spree::Order'`,
  # `Spree.customer_class.to_s`, plus any registered by apps) for resources that
  # expose tags via `acts_as_taggable_on :tags`. Used by the Admin API
  # `/tags` autocomplete endpoint to validate `taggable_type`. Apps extend
  # the list in an initializer:
  #
  #   Spree.taggable_types << 'MyApp::Seller'
  def self.taggable_types
    Rails.application.config.spree.taggable_types
  end

  def self.taggable_types=(value)
    Rails.application.config.spree.taggable_types = value
  end

  def self.reports
    Rails.application.config.spree.reports
  end

  def self.reports=(value)
    Rails.application.config.spree.reports = value
  end

  # Registry of the Getting Started onboarding tasks shown on the admin
  # dashboard. See {Spree::SetupTasks} for the extension API.
  #
  # @return [Spree::SetupTasks]
  def self.store_setup_tasks
    @store_setup_tasks ||= Spree::SetupTasks.new
  end

  def self.translatable_resources
    Rails.application.config.spree.translatable_resources
  end

  def self.translatable_resources=(value)
    Rails.application.config.spree.translatable_resources = value
  end

  def self.custom_fields
    Rails.application.config.spree.custom_fields
  end

  def self.metafields
    Spree::Deprecation.warn('Spree.metafields is deprecated and will be removed in Spree 6.1. Use Spree.custom_fields instead.') if defined?(Spree::Deprecation)
    custom_fields
  end

  def self.integrations
    Rails.application.config.spree.integrations
  end

  def self.integrations=(value)
    Rails.application.config.spree.integrations = value
  end

  # Registry mapping a numbered resource to the generator that produces its
  # document numbers. With no entry, the store's `document_number_format`
  # preference picks between the sequential and random strategies.
  #
  # @return [Spree::NumberGenerators::Registry]
  # @example Custom order numbers
  #   Spree.number_generators[:order] = 'MyApp::BranchOrderNumbers'
  def self.number_generators
    Rails.application.config.spree.number_generators
  end

  # Event subscribers that handle lifecycle and custom events
  # @example Adding a custom subscriber
  #   Spree.subscribers << MyApp::OrderNotificationSubscriber
  # @example Removing a built-in subscriber
  #   Spree.subscribers.delete(Spree::ExportSubscriber)
  def self.subscribers
    Rails.application.config.spree.subscribers
  end

  def self.subscribers=(value)
    Rails.application.config.spree.subscribers = value
  end

  def self.pricing
    Rails.application.config.spree.pricing
  end

  def self.pricing=(value)
    Rails.application.config.spree.pricing = value
  end

  # Registry of authentication strategy classes for the Store API.
  # @return [Spree::Authentication::StrategyRegistry]
  # @example Registering a third-party identity provider
  #   Spree.store_authentication_strategies.add(:auth0, MyApp::Auth::Auth0Strategy)
  # @example Removing a strategy
  #   Spree.store_authentication_strategies.remove(:email)
  def self.store_authentication_strategies
    Rails.application.config.spree.store_authentication_strategies
  end

  # @param value [Spree::Authentication::StrategyRegistry] the registry to use for Store API authentication dispatch
  # @return [Spree::Authentication::StrategyRegistry] the assigned registry
  def self.store_authentication_strategies=(value)
    Rails.application.config.spree.store_authentication_strategies = value
  end

  # Registry of authentication strategy classes for the Admin API.
  # @return [Spree::Authentication::StrategyRegistry]
  # @example Registering an SSO strategy for admin users
  #   Spree.admin_authentication_strategies.add(:okta, MyApp::Auth::OktaStrategy)
  def self.admin_authentication_strategies
    Rails.application.config.spree.admin_authentication_strategies
  end

  # @param value [Spree::Authentication::StrategyRegistry] the registry to use for Admin API authentication dispatch
  # @return [Spree::Authentication::StrategyRegistry] the assigned registry
  def self.admin_authentication_strategies=(value)
    Rails.application.config.spree.admin_authentication_strategies = value
  end

  # Registry of authentication strategy classes for the Seller API.
  #
  # Login policy is per surface, not per principal: marketplace sellers and the
  # store's own staff are both Spree.admin_user_class, so a store that requires
  # SSO for staff can still let sellers sign in with a password by leaving this
  # registry's :email strategy in place.
  #
  # @return [Spree::Authentication::StrategyRegistry]
  # @example Registering an SSO strategy for seller users
  #   Spree.seller_authentication_strategies.add(:okta, MyApp::Auth::OktaStrategy)
  def self.seller_authentication_strategies
    Rails.application.config.spree.seller_authentication_strategies
  end

  # @param value [Spree::Authentication::StrategyRegistry] the registry to use for Seller API authentication dispatch
  # @return [Spree::Authentication::StrategyRegistry] the assigned registry
  def self.seller_authentication_strategies=(value)
    Rails.application.config.spree.seller_authentication_strategies = value
  end

  # Semantic reporting registry — the queryable metric/dimension vocabulary.
  # Not to be confused with +Spree.analytics+ (storefront event tracking).
  #
  # @return [Spree::Reporting::Registry]
  def self.reporting
    Rails.application.config.spree.reporting
  end

  def self.reporting=(value)
    Rails.application.config.spree.reporting = value
  end

  def self.analytics
    @analytics ||= AnalyticsConfig.new
  end

  # Group analytics configuration options together, but still make it backwards compatible.
  class AnalyticsConfig
    def events
      Rails.application.config.spree.analytics_events
    end

    def events=(value)
      Rails.application.config.spree.analytics_events = value
    end

    def handlers
      Rails.application.config.spree.analytics_event_handlers
    end

    def handlers=(value)
      Rails.application.config.spree.analytics_event_handlers = value
    end
  end

  # The permission catalog — the grant vocabulary shared by staff roles and
  # secret API key scopes. Roles themselves are data (Spree::Role#permissions);
  # code only registers the vocabulary.
  #
  # @example Registering a resource from an extension
  #   Spree.permissions.register_resource(:reviews, group: :catalog, subjects: -> {
  #     [SpreeReviews::Review]
  #   })
  #
  # @return [Spree::PermissionConfiguration] the permission catalog
  def self.permissions
    @permissions ||= PermissionConfiguration.new
  end

  # Ransack configuration accessor for managing custom ransackable attributes,
  # associations, and scopes across Spree models.
  #
  # @example Adding custom searchable fields
  #   Spree.ransack.add_attribute(Spree::Product, :seller_id)
  #   Spree.ransack.add_scope(Spree::Product, :by_seller)
  #   Spree.ransack.add_association(Spree::Product, :seller)
  #
  # @return [Spree::RansackConfiguration] the ransack configuration instance
  def self.ransack
    @ransack ||= RansackConfiguration.new
  end

  class << self
    # Dynamic methods for core dependencies
    #
    # @example Getting a dependency (returns resolved class)
    #   Spree.cart_add_item_service.call(order: order, variant: variant)
    #
    # @example Setting a dependency
    #   Spree.cart_add_item_service = MyApp::CartAddItem
    def method_missing(method_name, *args, &block)
      base_name = method_name.to_s.chomp('=').to_sym

      return super unless core_dependency?(base_name)

      if method_name.to_s.end_with?('=')
        Spree::Dependencies.send(method_name, args.first)
      else
        # Returns resolved class (not string)
        Spree::Dependencies.send("#{method_name}_class")
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      base_name = method_name.to_s.chomp('=').to_sym
      core_dependency?(base_name) || super
    end

    private

    def core_dependency?(name)
      return false unless defined?(Spree::Dependencies)

      Spree::Dependencies.class::INJECTION_POINTS.include?(name) ||
        Spree::Dependencies.class::LEGACY_WORKFLOW_KEYS.key?(name) ||
        Spree::Dependencies.class::LEGACY_SERVICE_KEYS.key?(name) ||
        Spree::Dependencies.class::RENAMED_SERVICE_KEYS.key?(name)
    end
  end

  module Core
    class GatewayError < RuntimeError; end

    # The call may or may not have taken effect — a timeout, a dropped
    # connection, anything that leaves the answer at the provider rather than
    # in the response. Distinct from its parent because the safe reaction is
    # the opposite one: a definite failure can be retried, while an unknown
    # outcome must not be, since retrying is how the same money moves twice.
    class AmbiguousGatewayError < GatewayError; end

    class DestroyWithOrdersError < StandardError; end
  end
end

require 'spree/core/version'

require 'spree/core/number_generator'
require 'spree/number_generators/registry'
require 'spree/migrations'
require 'spree/translation_migrations'
require 'spree/validators'
require 'spree/core/engine'

require 'spree/i18n'
require 'spree/iso_data'
require 'spree/localized_number'
require 'spree/translations'
require 'spree/money'
require 'spree/service_module'
require 'spree/workflow'
require 'spree/analytics'
require 'spree/reporting'
require 'spree/events'
require 'spree/store_scope_guard'

require 'spree/core/controller_helpers/store'

require 'spree/core/preferences/store'
require 'spree/core/preferences/scoped_store'
require 'spree/core/preferences/runtime_configuration'
require 'spree/core/preferences/masking'

require 'spree/core/permission_configuration'
require 'spree/core/ransack_configuration'
require 'spree/core/pricing/context'
require 'spree/core/pricing/price_resolution'
require 'spree/core/pricing/resolver'
