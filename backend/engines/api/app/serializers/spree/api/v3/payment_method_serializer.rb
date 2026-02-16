module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        typelize name: :string, description: 'string | null', type: :string, session_required: :boolean

        attributes :name, :description, :type

        attribute :session_required do |payment_method|
          payment_method.session_required?
        end
      end
    end
  end
end
