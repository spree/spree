module Spree
  module Api
    # The configurable families whose subtypes each declare their own
    # `preferences`: the subtypes Spree ships, keyed by their wire `type`, with
    # the JSON Schema of each one's preferences. The OpenAPI components and the
    # SDK's preference types are both generated from it, so the two cannot
    # describe different shapes.
    module PreferenceFamilies
      # Family name => its registry. The name is the resource the family's
      # rows are serialized as, or, for calculators, the calculator's role.
      REGISTRIES = {
        'CommissionRule' => -> { Spree.commission_rules },
        'DeliveryCalculator' => -> { Spree::DeliveryMethod.calculators },
        'DeliveryMethodRule' => -> { Spree.delivery_method_rules },
        'Integration' => -> { Spree::Integration.registered_classes },
        'OrderRoutingRule' => -> { Spree.order_routing.rules },
        'PaymentMethod' => -> { Spree::PaymentMethod.providers },
        'PriceRule' => -> { Array(Spree.pricing&.rules) },
        'PromotionCalculator' => lambda {
          Spree.calculators.promotion_actions_create_adjustments + Spree.calculators.promotion_actions_create_item_adjustments
        },
        'PromotionRule' => -> { Spree.promotions.rules },
        'SellerRequirement' => -> { Spree.seller_requirements }
      }.freeze

      # The families a seller reads and writes.
      SELLER = %w[DeliveryCalculator DeliveryMethodRule].freeze

      # @param names [Array<String>] family names, every family by default
      # @return [Hash{String => Hash{String => Hash}}] family => { type => JSON Schema of its preferences }
      def self.schemas(names = REGISTRIES.keys)
        names.to_h do |name|
          classes = REGISTRIES.fetch(name).call.map { |entry| entry.is_a?(Class) ? entry : entry.to_s.constantize }
          [name, classes.uniq.sort_by(&:api_type).to_h { |klass| [klass.api_type, klass.preference_json_schema] }]
        end
      end

      # @param family [String] e.g. `PromotionRule`
      # @param type [String] e.g. `item_total`
      # @return [String] e.g. `PromotionRuleItemTotalPreferences`
      def self.member_name(family, type)
        "#{family}#{type.camelize}Preferences"
      end
    end
  end
end
