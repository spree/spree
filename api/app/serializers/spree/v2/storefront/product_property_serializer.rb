module Spree
  module V2
    module Storefront
      class ProductPropertySerializer < BaseSerializer
        set_type  :product_property

        attribute :value

        attribute :name,        &:property_name
        attribute :description, &:property_presentation
      end
    end
  end
end
