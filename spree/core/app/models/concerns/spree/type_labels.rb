module Spree
  # Names and describes each kind in a family of typed subclasses (promotion
  # rules, collection rules, …) from one translation scope keyed by
  # +api_type+, so the `/types` endpoints and dashboard pickers label
  # extension kinds the same way as built-in ones.
  #
  #   class Spree::PromotionRule < Spree.base_class
  #     include Spree::TypeLabels
  #     self.type_labels_scope = 'spree.promotion_rule_types'
  #   end
  #
  #   Spree::Promotion::Rules::Currency.human_name # => spree.promotion_rule_types.currency.name
  module TypeLabels
    extend ActiveSupport::Concern

    included do
      class_attribute :type_labels_scope, instance_writer: false
    end

    class_methods do
      # @return [String] the kind's name, falling back to its humanized +api_type+
      def human_name
        I18n.t("#{type_labels_scope}.#{api_type}.name", default: api_type.titleize)
      end

      # @return [String] what the kind does, empty when it has no translation
      def human_description
        I18n.t("#{type_labels_scope}.#{api_type}.description", default: '')
      end
    end

    # @return [String]
    def human_name = self.class.human_name

    # @return [String]
    def human_description = self.class.human_description
  end
end
