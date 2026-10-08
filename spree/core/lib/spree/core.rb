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
require 'alba'
require 'acts-as-taggable-on'
require 'awesome_nested_set'
require 'cancan'
require 'countries/global'
require 'friendly_id'
require 'json_schemer'
require 'jwt'
require 'liquid'
require 'spree/core/emails/escaped_output'
require 'monetize'
require 'mobility'
require 'mrml'
require 'name_of_person'
require 'nokogiri'
require 'oj'
require 'rails-html-sanitizer'
require 'rails-i18n'
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

  # Class settings hold a name rather than the class itself, so a reloaded
  # class is never served stale.
  def self.resolve_class_setting(name, value, constantize)
    raise "Spree.#{name} MUST be a String or Symbol object, not a Class object." if value.is_a?(Class)
    return unless value.is_a?(String) || value.is_a?(Symbol)

    constantize ? value.to_s.constantize : value.to_s
  end
  private_class_method :resolve_class_setting

  def self.storage_service_name(value)
    return Rails.application.config.active_storage.service unless value

    value.to_sym if value.is_a?(String) || value.is_a?(Symbol)
  end
  private_class_method :storage_service_name

  def self.base_class(constantize: true)
    resolve_class_setting(:base_class, @@base_class ||= 'Spree::Base', constantize)
  end

  def self.customer_class(constantize: true)
    resolve_class_setting(:customer_class, @@customer_class, constantize)
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
    resolve_class_setting(:admin_user_class, @@admin_user_class, constantize)
  end

  def self.private_storage_service_name
    storage_service_name(@@private_storage_service_name)
  end

  def self.public_storage_service_name
    storage_service_name(@@public_storage_service_name)
  end

  def self.queues
    @@queues ||= ActiveSupport::OrderedOptions.new.update(
      default: :default,
      events: :default,
      exports: :default,
      images: :default,
      imports: :default,
      products: :default,
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
      data_requests: :default,
      payouts: :default
    ).tap do |queues|
      # @deprecated The taxons queue was renamed to categories in 6.0; removed in 6.1.
      queues.define_singleton_method(:taxons) do
        Spree::Deprecation.warn('Spree.queues.taxons is deprecated and will be removed in Spree 6.1. Use Spree.queues.categories instead.') if defined?(Spree::Deprecation)
        categories
      end

      # @deprecated Renamed with the stock level rename in 6.0; removed in 6.1.
      #
      # The writer matters as much as the reader here: these are ordered options, so
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
    resolve_class_setting(:events_adapter_class, @@events_adapter_class ||= 'Spree::Events::Adapters::ActiveSupportNotifications', constantize)
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

  # Stable anonymous identifier for this Spree installation, kept on the
  # default store, which generates it when it is first saved.
  #
  # @return [String, nil] UUID, or nil before the default store exists
  def self.install_id
    Spree::Store.default&.preferred_install_id
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

  def self.spree_config
    Rails.application.config.spree
  end
  private_class_method :spree_config

  # Environment accessors for easier configuration access
  # Instead of Rails.application.config.spree.payment_methods
  # you can use Spree.payment_methods

  singleton_class.delegate :calculators, :calculators=, :validators, :validators=, :payment_methods, :payment_methods=,
                           :adjusters, :adjusters=, :fulfillment_providers, :fulfillment_providers=, :tracking_carriers,
                           :tracking_carriers=, :stock_splitters, :stock_splitters=, :delivery_method_rules,
                           :delivery_method_rules=, :order_routing, :order_routing=, :promotions, :promotions=,
                           :line_item_comparison_hooks, :line_item_comparison_hooks=, :data_feed_types, :data_feed_types=,
                           :export_types, :export_types=, :import_types, :import_types=, :taxon_rules, :taxon_rules=,
                           :translatable_resources, :translatable_resources=, :custom_fields, :integrations, :integrations=,
                           :pricing, :pricing=,
                           to: :spree_config

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
  singleton_class.delegate :media_viewable_types, :media_viewable_types=, to: :spree_config

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
  singleton_class.delegate :tax_providers, :tax_providers=, to: :spree_config

  # Pricing engines a store can be pointed at. Connector gems append their own,
  # so a merchant picks from what is actually installed.
  #
  # @return [Array<Class>]
  singleton_class.delegate :pricing_providers, :pricing_providers=, to: :spree_config

  # Inventory sources a store can be pointed at.
  #
  # @return [Array<Class>]
  singleton_class.delegate :inventory_providers, :inventory_providers=, to: :spree_config

  # How sellers get paid. Core ships {Spree::PayoutProvider::System}, which
  # keeps the books and leaves the operator to settle; a provider gem appends
  # one that moves the money itself.
  #
  # @return [Array<Class>]
  singleton_class.delegate :payout_providers, :payout_providers=, to: :spree_config

  # The provider a store pays through when it has named none.
  #
  # @return [Class]
  singleton_class.delegate :default_payout_provider, :default_payout_provider=, to: :spree_config

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
  singleton_class.delegate :password_validator, :password_validator=, to: :spree_config


  # Commission rule kinds selectable on a commission rate.
  #
  # @return [Array<Class>]
  singleton_class.delegate :commission_rules, :commission_rules=, to: :spree_config

  # Seller onboarding requirement kinds an operator can configure
  # (docs/plans/6.0-seller-onboarding-requirements.md).
  #
  # @return [Array<Class>]
  singleton_class.delegate :seller_requirements, :seller_requirements=, to: :spree_config

  # Quoting strategies selectable on a delivery method.
  #
  # @return [Array<Class>]
  singleton_class.delegate :delivery_rate_providers, :delivery_rate_providers=, to: :spree_config

  # Third-party pickup point networks selectable on a pickup-point delivery
  # method. Empty in core; carrier gems append theirs.
  #
  # @return [Array<Class>]
  singleton_class.delegate :pickup_point_providers, :pickup_point_providers=, to: :spree_config

  # Re-resolves every provider registry entry by name, in place.
  #
  # The registries hold class objects, and in development Zeitwerk reloads
  # the classes underneath them on each code change. The old objects stay in
  # the array, and a method on one — `service_catalog`, say — looks its
  # sibling constants up in a namespace that no longer exists, which is a
  # NameError on the admin provider catalog until the server restarts.
  # Swapping each entry for the class currently answering to its name fixes
  # that; in place, so a gem that appended its provider keeps its entry.
  # Anonymous classes have no name to resolve and are left alone.
  #
  # Run from the engine's to_prepare hook: every reload in development, once
  # at boot in production.
  #
  # @return [void]
  def self.refresh_provider_registries!
    [Rails.application.config.spree.delivery_rate_providers,
     Rails.application.config.spree.fulfillment_providers,
     Rails.application.config.spree.pickup_point_providers].compact.each do |registry|
      registry.map! { |entry| entry.is_a?(Module) && entry.name ? entry.name.constantize : entry }
    end
  end

  # Strategies selectable as a digital asset's source. Core registers the
  # uploaded-file default; host apps append providers that resolve a
  # deliverable elsewhere (a licensing system, a code pool).
  #
  # @return [Array<Class>]
  singleton_class.delegate :digital_asset_providers, :digital_asset_providers=, to: :spree_config

  # Fulfillment profile kinds selectable when creating a profile.
  #
  # @return [Array<Class>]
  singleton_class.delegate :delivery_profile_types, :delivery_profile_types=, to: :spree_config

  # Class-name strings (`'Spree::Product'`, `'Spree::Order'`,
  # `Spree.customer_class.to_s`, plus any registered by apps) for resources that
  # expose tags via `acts_as_taggable_on :tags`. Used by the Admin API
  # `/tags` autocomplete endpoint to validate `taggable_type`. Apps extend
  # the list in an initializer:
  #
  #   Spree.taggable_types << 'MyApp::Seller'
  singleton_class.delegate :taggable_types, :taggable_types=, to: :spree_config

  # Class-name strings for the models that may be recorded as having performed
  # an action — what an `acted_by` association's `*_type` column is allowed to
  # hold. The admin user class and `Spree::ApiKey` ship registered; an
  # extension adds its own App or bot class in an initializer:
  #
  #   Spree.actor_classes << 'MyApp::App'
  #
  # A class listed here includes {Spree::Actor}, so a timeline can name it.
  # See docs/plans/6.0-action-actors.md.
  #
  # @return [Array<String>]
  singleton_class.delegate :actor_classes, :actor_classes=, to: :spree_config


  # Registry of the Getting Started onboarding tasks shown on the admin
  # dashboard. See {Spree::SetupTasks} for the extension API.
  #
  # @return [Spree::SetupTasks]
  def self.store_setup_tasks
    @store_setup_tasks ||= Spree::SetupTasks.new
  end

  def self.metafields
    Spree::Deprecation.warn('Spree.metafields is deprecated and will be removed in Spree 6.1. Use Spree.custom_fields instead.') if defined?(Spree::Deprecation)
    custom_fields
  end

  # Registry mapping a numbered resource to the generator that produces its
  # document numbers. With no entry, the store's `document_number_format`
  # preference picks between the sequential and random strategies.
  #
  # @return [Spree::NumberGenerators::Registry]
  # @example Custom order numbers
  #   Spree.number_generators[:order] = 'MyApp::BranchOrderNumbers'
  singleton_class.delegate :number_generators, to: :spree_config

  # The email templates merchants may edit in the dashboard.
  #
  # @return [Spree::Emails::EditableTemplates]
  def self.editable_email_templates
    @editable_email_templates ||= Spree::Emails::EditableTemplates.new
  end

  # Event subscribers that handle lifecycle and custom events
  # @example Adding a custom subscriber
  #   Spree.subscribers << MyApp::OrderNotificationSubscriber
  # @example Removing a built-in subscriber
  #   Spree.subscribers.delete(Spree::ExportSubscriber)
  singleton_class.delegate :subscribers, :subscribers=, to: :spree_config

  # Registry of authentication strategy classes for the Store API.
  # @return [Spree::Authentication::StrategyRegistry]
  # @example Registering a third-party identity provider
  #   Spree.store_authentication_strategies.add(:auth0, MyApp::Auth::Auth0Strategy)
  # @example Removing a strategy
  #   Spree.store_authentication_strategies.remove(:email)
  # @param value [Spree::Authentication::StrategyRegistry] the registry to use for Store API authentication dispatch
  # @return [Spree::Authentication::StrategyRegistry] the assigned registry
  singleton_class.delegate :store_authentication_strategies, :store_authentication_strategies=, to: :spree_config

  # Registry of authentication strategy classes for the Admin API.
  # @return [Spree::Authentication::StrategyRegistry]
  # @example Registering an SSO strategy for admin users
  #   Spree.admin_authentication_strategies.add(:okta, MyApp::Auth::OktaStrategy)
  # @param value [Spree::Authentication::StrategyRegistry] the registry to use for Admin API authentication dispatch
  # @return [Spree::Authentication::StrategyRegistry] the assigned registry
  singleton_class.delegate :admin_authentication_strategies, :admin_authentication_strategies=, to: :spree_config

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
  # @param value [Spree::Authentication::StrategyRegistry] the registry to use for Seller API authentication dispatch
  # @return [Spree::Authentication::StrategyRegistry] the assigned registry
  singleton_class.delegate :seller_authentication_strategies, :seller_authentication_strategies=, to: :spree_config

  # Semantic reporting registry — the queryable metric/dimension vocabulary.
  #
  # @return [Spree::Reporting::Registry]
  singleton_class.delegate :reporting, :reporting=, to: :spree_config

  # The permission catalog — the grant vocabulary shared by staff roles and
  # secret API key scopes. Roles themselves are data (Spree::Role#permissions);
  # code only registers the vocabulary.
  #
  # @example Registering a scope from an extension
  #   Spree.permissions.register_scope(:reviews, group: :catalog, resources: -> {
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

    # A gift card that could not be taken back off a cart or draft order
    # holding its balance. No gateway is involved — reported separately so a
    # money discrepancy is not triaged alongside payment outages.
    class GiftCardHoldReleaseFailed < RuntimeError; end

    # A label purchase that failed inside the one-click fulfill path, where
    # the parcel ships regardless — reported so the merchant's error tracker
    # sees why there is no label.
    class LabelPurchaseFailed < RuntimeError; end

    # A carrier refusing to sell a label, in its own words. Raised by a
    # provider when it knows why — a warehouse with no address, an
    # unserviceable destination — so the merchant reads the actual reason
    # instead of being sent to check a connection that is fine.
    class LabelPurchaseRefused < RuntimeError; end

    # A carrier refusing to void a label, in its own words — a parcel it has
    # already collected, a label past its void window. Raised by a provider
    # when it knows why, so the merchant reads the reason.
    class LabelRefundRefused < RuntimeError; end

    # A label the carrier refused to refund while a parcel was being
    # cancelled. The cancellation proceeds; the postage is the merchant's to
    # chase, so it is reported rather than dropped.
    class LabelRefundFailed < RuntimeError; end

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
require 'spree/validators'
require 'spree/core/engine'

require 'spree/i18n'
require 'spree/iso_data'
require 'spree/localized_number'
require 'spree/measurement'
require 'spree/translations'
require 'spree/money'
require 'spree/service_module'
require 'spree/workflow'
require 'spree/reporting'
require 'spree/events'
require 'spree/store_scope_guard'

# Not autoloaded from app/: the registry keeps registered steps in
# class-level state, which a reload would discard.
require 'spree/checkout/step'
require 'spree/checkout/requirement'
require 'spree/checkout/registry'
require 'spree/emails/editable_templates'
require 'spree/checkout/default_requirements'
require 'spree/checkout/requirements'

require 'spree/core/controller_helpers/store'

require 'spree/core/preferences/runtime_configuration'
require 'spree/core/preferences/masking'
require 'spree/core/preferences/json_conversion'

require 'spree/core/permission_configuration'
require 'spree/core/ransack_configuration'
require 'spree/core/pricing/context'
require 'spree/core/pricing/price_resolution'
require 'spree/core/pricing/resolver'
require 'spree/core/tax/provider_error'
