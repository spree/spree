module Spree
  class PaymentSource < Spree.base_class
    include Spree::Metadata

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :user, class_name: Spree.user_class.to_s, optional: true

    validates_uniqueness_of :gateway_payment_profile_id, scope: :type
  end
end
