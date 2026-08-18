# frozen_string_literal: true

module Spree
  module CommissionRules
    # Charge this rate only for products filed under one of these categories.
    #
    # A category matches its descendants too, so a rate on "Electronics"
    # governs a camera under "Electronics → Cameras" and a marketplace does not
    # restate the rule on every new leaf. The walk is done once per order by
    # Spree::Commissions::Context, not per rule.
    class CategoryRule < Spree::CommissionRule
      preference :category_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(
                   klass: Spree::Category,
                   scope: ->(rule) { rule.store.categories }
                 )

      # @return [Array<Spree::Category>]
      def categories
        return [] if preferred_category_ids.blank?

        Spree::Category.where(id: preferred_category_ids)
      end

      def applicable?(context)
        return false if preferred_category_ids.blank?

        wanted = preferred_category_ids.map(&:to_s).to_set
        context.categories.any? { |category| wanted.include?(category.id.to_s) }
      end
    end
  end
end
