module Spree
  module Api
    module V3
      class LineItemSerializer < BaseSerializer
        typelize_from Spree::LineItem
        typelize name: :string, slug: :string, options_text: :string,
                 display_price: :string, display_total: :string,
                 display_adjustment_total: :string, display_additional_tax_total: :string,
                 display_included_tax_total: :string, display_promo_total: :string,
                 display_pre_tax_amount: :string, display_discounted_amount: :string,
                 display_compare_at_amount: 'string | null'

        attributes :id, :variant_id, :quantity, :name, :slug, :options_text,
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
