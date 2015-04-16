module Spree
  class LineItemSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.line_item_attributes
    attributes :id, :variant_id, :quantity, :price,
               :single_display_amount, :total, :display_total,
               :display_amount

    has_one :variant, serializer: Spree::SmallVariantSerializer
    has_many :adjustments

  end
end
