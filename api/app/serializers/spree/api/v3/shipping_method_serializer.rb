module Spree
  module Api
    module V3
      class ShippingMethodSerializer < BaseSerializer
        attributes :id, :name, :code, :tracking_url, :admin_name,
                   created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end
