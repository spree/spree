module Spree
  module Api
    module V2
      module Platform
        class ShippingMethodSerializer < BaseSerializer
          attributes :name, :code, :admin_name, :display_on, :tracking_url, :created_at, :updated_at, :deleted_at, :public_metadata, :private_metadata

          has_many :shipping_categories
          has_many :shipping_rates
          belongs_to :tax_category
          has_one :calculator
        end
      end
    end
  end
end
