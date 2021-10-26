module Spree
  module Api
    module V2
      module Platform
        class ShippingMethodSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :shipping_categories, through: :shipping_method_categories
          has_many :shipping_rates
          belongs_to :tax_category
          has_one :calculator
        end
      end
    end
  end
end
