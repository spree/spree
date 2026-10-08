module Spree
  # Wire shorthand for the plain-Ruby strategy classes a merchant picks from a
  # registry (fulfillment, delivery-rate, pickup-point, payout and digital
  # asset providers, order routing strategies). Records keep storing the class
  # name; the API reads and writes this shorthand, so the contract never
  # carries a Ruby constant.
  #
  #   class Spree::FulfillmentProvider::Base
  #     extend Spree::ApiTyped
  #   end
  #
  #   Spree::FulfillmentProvider::Manual.api_type  # => "manual"
  #   SpreeEasyPost::FulfillmentProvider.api_type  # => "easy_post"
  module ApiTyped
    # The demodulized + underscored leaf. Gems name their class after the
    # family (`SpreeEasyPost::FulfillmentProvider`, `Acme::Strategy`), where the leaf would
    # collapse every gem to one value — those derive it from the gem's module
    # instead, matching {Spree::Integration.api_type}. Override to keep the
    # value stable across a class rename.
    #
    # @return [String]
    def api_type
      leaf = name.to_s.demodulize
      outer = name.to_s.deconstantize.demodulize.delete_prefix('Spree')

      return leaf.underscore unless (leaf.end_with?('Provider') || leaf == 'Strategy') && outer.present?

      outer.underscore
    end

    # The registered class answering to a wire shorthand, or nil.
    #
    # @param registry [Array<Class, String>]
    # @param api_type [String, nil]
    # @return [Class, nil]
    def self.find(registry, api_type)
      return nil if api_type.blank?

      Array(registry).map { |entry| entry.is_a?(Class) ? entry : entry.to_s.safe_constantize }.
        compact.find { |klass| klass.api_type == api_type.to_s }
    end

    # The registered class a record's stored class name points at, or nil
    # when it is no longer registered (a typo, an uninstalled gem) — so a
    # stored string is never constantized outside the registry.
    #
    # @param registry [Array<Class>]
    # @param class_name [String, nil]
    # @return [Class, nil]
    def self.registered_class(registry, class_name)
      return nil if class_name.blank?

      Array(registry).find { |klass| klass.to_s == class_name.to_s }
    end

    # The class name a record stores for a value arriving from the API. A
    # registered shorthand becomes its class name; anything else passes through
    # unchanged so the record's own inclusion validation rejects it.
    #
    # @param registry [Array<Class, String>]
    # @param value [String, nil]
    # @return [String, nil]
    def self.class_name_for(registry, value)
      return value if value.blank?

      find(registry, value)&.to_s || value
    end

    # The shorthand for a stored class name. A class that is no longer
    # registered (an uninstalled gem) is shortened the same way rather than
    # constantized.
    #
    # @param class_name [String, nil]
    # @return [String, nil]
    def self.api_type_for(class_name)
      return nil if class_name.blank?

      klass = class_name.to_s.safe_constantize
      klass.respond_to?(:api_type) ? klass.api_type : class_name.to_s.demodulize.underscore
    end
  end
end
