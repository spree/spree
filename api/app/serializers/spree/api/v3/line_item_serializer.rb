module Spree
  module Api
    module V3
      class LineItemSerializer < BaseSerializer
        typelize variant_id: :string, quantity: :number, name: :string, slug: :string, options_text: :string,
                 price: :number, display_price: :string, total: :number, display_total: :string,
                 adjustment_total: :number, display_adjustment_total: :string,
                 additional_tax_total: :number, display_additional_tax_total: :string,
                 included_tax_total: :number, display_included_tax_total: :string,
                 promo_total: :number, display_promo_total: :string,
                 pre_tax_amount: :number, display_pre_tax_amount: :string,
                 discounted_amount: :number, display_discounted_amount: :string,
                 compare_at_amount: 'number | null', display_compare_at_amount: 'string | null'

        attribute :variant_id do |line_item|
          line_item.variant&.prefix_id
        end

        attributes :quantity, :name, :slug, :options_text,
                   :price, :display_price, :total, :display_total,
                   :adjustment_total, :display_adjustment_total,
                   :additional_tax_total, :display_additional_tax_total,
                   :included_tax_total, :display_included_tax_total,
                   :promo_total, :display_promo_total,
                   :pre_tax_amount, :display_pre_tax_amount,
                   :discounted_amount, :display_discounted_amount,
                   :compare_at_amount, :display_compare_at_amount,
                   created_at: :iso8601, updated_at: :iso8601

        many :images, resource: Spree.api.image_serializer
        many :option_values, resource: Spree.api.option_value_serializer
      end
    end
  end
end
