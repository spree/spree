module Spree
  class PaymentSource < Spree::Base
    include Metadata

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :user, class_name: 'Spree::User', optional: true
  end
end
