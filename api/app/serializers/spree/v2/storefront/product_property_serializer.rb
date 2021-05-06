module Spree
  module V2
    module Storefront
      class ProductPropertySerializer < BaseSerializer
        set_type  :product_property

        attribute :value, :filter_param

        attribute :name do |product_property|
          product_property.property_name
        end

        attribute :description do |product_property|
          product_property.property_presentation
        end
      end
    end
  end
end
