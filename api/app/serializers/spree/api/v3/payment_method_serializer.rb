module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        attributes :id, :name, :description, :type, :active,
                   created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end
