require 'rails/all'
require 'active_merchant'
require 'acts_as_list'
require 'awesome_nested_set'
require 'cancan'
require 'friendly_id'
require 'kaminari'
require 'mail'
require 'monetize'
require 'paranoia'
require 'mini_magick'
require 'premailer/rails'
require 'ransack'
require 'responders'
require 'state_machines-activerecord'
require 'active_storage_validations'

# This is required because ActiveModel::Validations#invalid? conflicts with the
# invalid state of a Payment. In the future this should be removed.
StateMachines::Machine.ignore_method_conflicts = true

module Spree
  mattr_accessor :user_class

  def self.user_class(constantize: true)
    if @@user_class.is_a?(Class)
      raise 'Spree.user_class MUST be a String or Symbol object, not a Class object.'
    elsif @@user_class.is_a?(String) || @@user_class.is_a?(Symbol)
      constantize ? @@user_class.to_s.constantize : @@user_class.to_s
    end
  end

  def self.admin_path
    Spree::Config[:admin_path]
  end

  # Used to configure admin_path for Spree
  #
  # Example:
  #
  # write the following line in `config/initializers/spree.rb`
  #   Spree.admin_path = '/custom-path'

  def self.admin_path=(path)
    Spree::Config[:admin_path] = path
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
    yield(Spree::Config)
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
require 'spree/core/engine'

require 'spree/i18n'
require 'spree/localized_number'
require 'spree/money'
require 'spree/permitted_attributes'
require 'spree/service_module'
require 'spree/dependencies_helper'
require 'spree/database_type_utilities'

require 'spree/core/importer'
require 'spree/core/query_filters'
require 'spree/core/product_duplicator'
require 'spree/core/controller_helpers/auth'
require 'spree/core/controller_helpers/common'
require 'spree/core/controller_helpers/order'
require 'spree/core/controller_helpers/search'
require 'spree/core/controller_helpers/store'
require 'spree/core/controller_helpers/strong_parameters'
require 'spree/core/controller_helpers/currency_helpers'
