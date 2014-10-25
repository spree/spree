require 'rails/all'
require 'active_merchant'
require 'acts_as_list'
require 'awesome_nested_set'
require 'cancan'
require 'friendly_id'
require 'font-awesome-rails'
require 'kaminari'
require 'mail'
require 'monetize'
require 'paperclip'
require 'paranoia'
require 'premailer/rails'
require 'ransack'
require 'responders'
require 'state_machine'

module Spree

  mattr_accessor :user_class

  def self.user_class
    if @@user_class.is_a?(Class)
      raise "Spree.user_class MUST be a String or Symbol object, not a Class object."
    elsif @@user_class.is_a?(String) || @@user_class.is_a?(Symbol)
      @@user_class.to_s.constantize
    end
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
  def self.config(&block)
    yield(Spree::Config)
  end

  module Core
    autoload :ProductFilters, "spree/core/product_filters"

    class GatewayError < RuntimeError; end
    class DestroyWithOrdersError < StandardError; end
  end
end

require 'spree/core/version'

require 'spree/core/environment_extension'
require 'spree/core/environment/calculators'
require 'spree/core/environment'
require 'spree/promo/environment'
require 'spree/migrations'
require 'spree/core/engine'

require 'spree/i18n'
require 'spree/money'

require 'spree/permitted_attributes'
require 'spree/core/delegate_belongs_to'
require 'spree/core/permalinks'
require 'spree/core/product_duplicator'
require 'spree/core/controller_helpers/auth'
require 'spree/core/controller_helpers/common'
require 'spree/core/controller_helpers/order'
require 'spree/core/controller_helpers/respond_with'
require 'spree/core/controller_helpers/search'
require 'spree/core/controller_helpers/ssl'
require 'spree/core/controller_helpers/store'
require 'spree/core/controller_helpers/strong_parameters'

require 'spree/core/importer'

module StateMachine
  module Integrations
    # Hack waiting on https://github.com/pluginaweek/state_machine/pull/275
    module ActiveModel
      public :around_validation
    end

    module ActiveRecord
      protected
        # Initializes static states
        def define_static_state_initializer
          # This is the only available hook where the default set of attributes
          # can be overridden for a new object *prior* to the processing of the
          # attributes passed into #initialize
          define_helper :class, <<-end_eval, __FILE__, __LINE__ + 1
            def default_attributes(*) #:nodoc:
              result = super
              # No need to pass in an object, since the overrides will be forced
              self.state_machines.initialize_states(nil, :static => :force, :dynamic => false, :to => result)
              result
            end
          end_eval
        end
    end
  end

  class Machine
    # Initializes the state on the given object.  Initial values are only set if
    # the machine's attribute hasn't been previously initialized.
    #
    # Configuration options:
    # * <tt>:force</tt> - Whether to initialize the state regardless of its
    #   current value
    # * <tt>:to</tt> - A AttributeSet of the initial value in instead of writing
    #   directly to the object
    def initialize_state(object, options = {})
      state = initial_state(object)
      if state && (options[:force] || initialize_state?(object))
        value = state.value

        if attribute_set = options[:to]
          attribute_set.write_from_user(attribute.to_s, value)
        else
          write(object, :state, value)
        end
      end
    end
  end
end
