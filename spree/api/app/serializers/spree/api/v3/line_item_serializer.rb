module Spree
  module Api
    module V3
      class LineItemSerializer < BaseSerializer
        typelize variant_id: :string, quantity: :number, currency: :string,
                 name: :string, slug: :string, options_text: :string,
                 price: [:string, nullable: true], display_price: [:string, nullable: true],
                 total: [:string, nullable: true], display_total: [:string, nullable: true],
                 adjustment_total: [:string, nullable: true], display_adjustment_total: [:string, nullable: true],
                 additional_tax_total: [:string, nullable: true], display_additional_tax_total: [:string, nullable: true],
                 included_tax_total: [:string, nullable: true], display_included_tax_total: [:string, nullable: true],
                 discount_total: [:string, nullable: true], display_discount_total: [:string, nullable: true],
                 pre_tax_amount: [:string, nullable: true], display_pre_tax_amount: [:string, nullable: true],
                 discounted_amount: [:string, nullable: true], display_discounted_amount: [:string, nullable: true],
                 compare_at_amount: [:string, nullable: true], display_compare_at_amount: [:string, nullable: true],
                 thumbnail_url: [:string, nullable: true]

        attribute :variant_id do |line_item|
          line_item.variant&.prefixed_id
        end

        attributes :quantity, :currency, :name, :slug, :options_text

        # Nulled for gated (prices_hidden) guests so the cart's line items can't
        # leak the prices that product/variant serializers already withhold.
        money_attributes :price, :display_price, :total, :display_total,
                         :adjustment_total, :display_adjustment_total,
                         :additional_tax_total, :display_additional_tax_total,
                         :included_tax_total, :display_included_tax_total,
                         :discount_total, :display_discount_total,
                         :pre_tax_amount, :display_pre_tax_amount,
                         :discounted_amount, :display_discounted_amount,
                         :display_compare_at_amount

        # Return compare_at_amount as string, nil if zero
        attribute :compare_at_amount do |line_item|
          next nil if params[:hide_prices]

          amount = line_item.compare_at_amount
          amount.present? && amount.positive? ? amount.to_s : nil
        end

        # Thumbnail URL for line item (variant thumbnail or product thumbnail)
        attribute :thumbnail_url do |line_item|
          image_url_for(line_item.thumbnail)
        end

        many :option_values, resource: proc { Spree.api.option_value_serializer }
        many :digital_links, resource: proc { Spree.api.digital_link_serializer }
      end
    end
  end
end
