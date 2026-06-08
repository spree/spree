module Spree
  module OrderRouting
    # Shared registry lookup for the order-routing extension points whose
    # selectable classes are configured via a +Rails.application.config.spree.*+
    # array: strategies (Spree::OrderRouting::Strategy::Base) and rule kinds
    # (Spree::OrderRoutingRule). The registry is the curated allowlist; for rules
    # STI still handles runtime dispatch. Declare the backing config with
    # +registered_via+. See docs/plans/6.0-order-routing.md.
    module Registrable
      extend ActiveSupport::Concern

      included do
        class_attribute :order_routing_registry_key, instance_accessor: false
      end

      class_methods do
        # @param key [Symbol] the Spree config accessor backing this registry
        #   (e.g. +:order_routing_strategies+)
        def registered_via(key)
          self.order_routing_registry_key = key
        end

        # @return [Array<Class>] registered (selectable) classes
        def registered
          Array(Spree.public_send(order_routing_registry_key))
        end

        # @param klass_name [String, Class, nil]
        # @return [Class, nil] the registered class matching the name, if any
        def registered_class(klass_name)
          return if klass_name.blank?

          registered.find { |klass| klass.to_s == klass_name.to_s }
        end

        # @param klass_name [String, Class, nil]
        # @return [Boolean] whether the class is registered
        def registered?(klass_name)
          !registered_class(klass_name).nil?
        end
      end
    end
  end
end
