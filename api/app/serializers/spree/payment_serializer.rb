module Spree
  class PaymentSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.payment_attributes
    attributes :id, :source_type, :source_id, :amount, :display_amount,
               :payment_method_id, :response_code, :state, :avs_response,
               :created_at, :updated_at, :source

    has_one :payment_method

    def source
      if object.source
        attributes = object.source.attributes

        unless scope.current_api_user.has_spree_role? "admin"
          attributes.delete("gateway_payment_profile_id")
          attributes.delete("gateway_customer_profile_id")
        end

        return attributes
      else
        nil
      end
    end
  end
end
