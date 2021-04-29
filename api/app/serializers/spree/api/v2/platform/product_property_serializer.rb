module Spree
  module Api
    module V2
      module Platform
        class ProductPropertySerializer < BaseSerializer
          set_type  :product_property

          attribute :value

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
end
