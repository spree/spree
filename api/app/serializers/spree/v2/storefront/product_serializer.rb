module Spree
  module V2
    module Storefront
      class ProductSerializer < BaseSerializer
        set_type :product

        attributes :name, :description, :price, :currency, :display_price,
                   :available_on, :slug, :meta_description, :meta_keywords,
                   :updated_at

        attribute :purchasable do |product|
          product.purchasable?
        end

        attribute :in_stock do |product|
          product.in_stock?
        end

        attribute :backorderable do |product|
          product.backorderable?
        end

        has_many :variants
        has_many :option_types
        has_many :product_properties

        has_one  :default_variant,
          object_method_name: :master,
          id_method_name:     :master_id,
          record_type:        :variant,
          serializer:         :variant
      end
    end
  end
end
