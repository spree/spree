module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true], type: :string,
                 session_required: :boolean, source_required: :boolean

        attributes :name, :description

        attribute :type do |payment_method|
          payment_method.class.api_type
        end

        attribute :session_required do |payment_method|
          payment_method.session_required?
        end

        attribute :source_required do |payment_method|
          payment_method.source_required?
        end
      end
    end
  end
end
