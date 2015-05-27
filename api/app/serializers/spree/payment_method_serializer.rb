module Spree
  class PaymentMethodSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.payment_method_attributes
    attributes  :id, :type, :name, :description, :active,
                :auto_capture, :preferences
  end
end
