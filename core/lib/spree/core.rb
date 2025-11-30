require 'ostruct'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_job/railtie'
require 'active_model/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_text/engine'
require 'action_cable/engine'

require 'mail'
require 'action_mailer/railtie'

require 'active_merchant'
require 'acts_as_list'
require 'acts-as-taggable-on'
require 'auto_strip_attributes'
require 'awesome_nested_set'
require 'cancan'
require 'countries/global'
require 'friendly_id'
require 'kaminari'
require 'monetize'
require 'mobility'
require 'name_of_person'
require 'paranoia'
require 'ransack'
require 'state_machines-activerecord'
require 'active_storage_validations'
require 'request_store'
require 'wannabe_bool'
require 'geocoder'
require 'oembed'
require 'safely_block'

# This is required because ActiveModel::Validations#invalid? conflicts with the
# invalid state of a Payment. In the future this should be removed.
StateMachines::Machine.ignore_method_conflicts = true

module Spree
  mattr_accessor :base_class, :user_class, :admin_user_class,
                 :private_storage_service_name, :public_storage_service_name,
                 :cdn_host, :root_domain, :searcher_class, :queues,
                 :google_places_api_key, :screenshot_api_token

  def self.base_class(constantize: true)
    @@base_class ||= 'Spree::Base'
    if @@base_class.is_a?(Class)
      raise 'Spree.base_class MUST be a String or Symbol object, not a Class object.'
    elsif @@base_class.is_a?(String) || @@base_class.is_a?(Symbol)
      constantize ? @@base_class.to_s.constantize : @@base_class.to_s
    end
  end

  def self.user_class(constantize: true)
    if @@user_class.is_a?(Class)
      raise 'Spree.user_class MUST be a String or Symbol object, not a Class object.'
    elsif @@user_class.is_a?(String) || @@user_class.is_a?(Symbol)
      constantize ? @@user_class.to_s.constantize : @@user_class.to_s
    end
  end

  def self.admin_user_class(constantize: true)
    @@admin_user_class ||= @@user_class

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
      exports: :default,
      images: :default,
      imports: :default,
      reports: :default,
      variants: :default,
      taxons: :default,
      stock_location_stock_items: :default,
      coupon_codes: :default,
      webhooks: :default,
      themes: :default,
      addresses: :default,
      gift_cards: :default
    )
  end

  def self.searcher_class(constantize: true)
    @@searcher_class ||= 'Spree::Core::Search::Base'

    if @@searcher_class.is_a?(Class)
      raise 'Spree.searcher_class MUST be a String or Symbol object, not a Class object.'
    elsif @@searcher_class.is_a?(String) || @@searcher_class.is_a?(Symbol)
      constantize ? @@searcher_class.to_s.constantize : @@searcher_class.to_s
    end
  end

  def self.google_places_api_key
    @@google_places_api_key
  end

  def self.screenshot_api_token
    @@screenshot_api_token
  end

  def self.always_use_translations?
    Spree::Config.always_use_translations
  end

  def self.use_translations?
    Spree::Config.always_use_translations || I18n.default_locale != I18n.locale
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

  def self.stock_splitters
    Rails.application.config.spree.stock_splitters
  end

  def self.stock_splitters=(value)
    Rails.application.config.spree.stock_splitters = value
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

  def self.reports
    Rails.application.config.spree.reports
  end

  def self.reports=(value)
    Rails.application.config.spree.reports = value
  end

  def self.translatable_resources
    Rails.application.config.spree.translatable_resources
  end

  def self.translatable_resources=(value)
    Rails.application.config.spree.translatable_resources = value
  end

  def self.metafields
    Rails.application.config.spree.metafields
  end

  def self.integrations
    Rails.application.config.spree.integrations
  end

  def self.integrations=(value)
    Rails.application.config.spree.integrations = value
  end

  # Page Builder configuration accessor
  def self.page_builder
    @page_builder ||= PageBuilderConfig.new
  end

  class PageBuilderConfig
    def themes
      Rails.application.config.spree.themes
    end

    def themes=(value)
      Rails.application.config.spree.themes = value
    end

    def theme_layout_sections
      Rails.application.config.spree.theme_layout_sections
    end

    def theme_layout_sections=(value)
      Rails.application.config.spree.theme_layout_sections = value
    end

    def pages
      Rails.application.config.spree.pages
    end

    def pages=(value)
      Rails.application.config.spree.pages = value
    end

    def page_sections
      Rails.application.config.spree.page_sections
    end

    def page_sections=(value)
      Rails.application.config.spree.page_sections = value
    end

    def page_blocks
      Rails.application.config.spree.page_blocks
    end

    def page_blocks=(value)
      Rails.application.config.spree.page_blocks = value
    end
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

  # Permission configuration accessor for managing role-to-permission-set mappings.
  #
  # @example Assigning permission sets to a role
  #   Spree.permissions.assign(:customer_service, [
  #     Spree::PermissionSets::OrderDisplay,
  #     Spree::PermissionSets::UserManagement
  #   ])
  #
  # @example Clearing permission sets from a role
  #   Spree.permissions.clear(:customer_service)
  #
  # @return [Spree::PermissionConfiguration] the permission configuration instance
  def self.permissions
    @permissions ||= PermissionConfiguration.new
  end

  module Core
    autoload :ProductFilters, 'spree/core/product_filters'
    autoload :TokenGenerator, 'spree/core/token_generator'

    class GatewayError < RuntimeError; end
    class DestroyWithOrdersError < StandardError; end
  end
end

require 'spree/core/version'

require 'spree/core/number_generator'
require 'spree/migrations'
require 'spree/translation_migrations'
require 'spree/core/engine'

require 'spree/i18n'
require 'spree/localized_number'
require 'spree/money'
require 'spree/permitted_attributes'
require 'spree/service_module'
require 'spree/database_type_utilities'
require 'spree/analytics'

require 'spree/core/partials'
require 'spree/core/importer'
require 'spree/core/query_filters'
require 'spree/core/controller_helpers/auth'
require 'spree/core/controller_helpers/common'
require 'spree/core/controller_helpers/order'
require 'spree/core/controller_helpers/search'
require 'spree/core/controller_helpers/store'
require 'spree/core/controller_helpers/strong_parameters'
require 'spree/core/controller_helpers/locale'
require 'spree/core/controller_helpers/currency'
require 'spree/core/controller_helpers/turbo'

require 'spree/core/preferences/store'
require 'spree/core/preferences/scoped_store'
require 'spree/core/preferences/runtime_configuration'

require 'spree/core/webhooks'
require 'spree/core/permission_configuration'
