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
