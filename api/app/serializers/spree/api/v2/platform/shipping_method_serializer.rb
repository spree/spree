module Spree
  module Api
    module V2
      module Platform
        class ShippingMethodSerializer < BaseSerializer
          attributes :name, :code, :admin_name, :display_on, :tracking_url, :created_at, :updated_at, :deleted_at, :public_metadata, :private_metadata

          has_many :shipping_categories, serializer: Spree::Api::Dependencies.platform_shipping_category_serializer.constantize
          has_many :shipping_rates, serializer: Spree::Api::Dependencies.platform_shipping_rate_serializer.constantize
          belongs_to :tax_category, serializer: Spree::Api::Dependencies.platform_tax_category_serializer.constantize
          has_one :calculator, serializer: Spree::Api::Dependencies.platform_calculator_serializer.constantize
        end
      end
    end
  end
end
