module Spree
  module V2
    module Storefront
      class ProductSerializer < BaseSerializer
        set_type   :product

        attributes :id, :name, :description, :price, :display_price,
                   :available_on, :slug, :meta_description, :meta_keywords,
                   :shipping_category_id, :taxon_ids, :total_on_hand

        has_many   :variants
        has_many   :option_types
      end
    end
  end
end
