module Spree
  module Api
    module V2
      module Platform
        class ShippingMethodSerializer < BaseSerializer
          attributes :name, :code, :admin_name, :display_on, :tracking_url, :created_at, :updated_at, :deleted_at, :public_metadata, :private_metadata

          has_many :shipping_categories, serializer: Spree.api.platform_shipping_category_serializer
          has_many :shipping_rates, serializer: Spree.api.platform_shipping_rate_serializer
          belongs_to :tax_category, serializer: Spree.api.platform_tax_category_serializer
          has_one :calculator, serializer: Spree.api.platform_calculator_serializer
        end
      end
    end
  end
end
