module Spree
  class PaymentSource < Spree::Base
    self.abstract_class = true

    belongs_to :payment_method

    # Refactor me to polymorphic association
    belongs_to :user, class_name: Spree.user_class, foreign_key: 'user_id'
    has_many :payments, as: :source

    # TODO This has to go into the UserPaymentSource class
    # after_save :ensure_one_default

    attr_accessor :imported

    scope :with_payment_profile, -> { where('gateway_customer_profile_id IS NOT NULL') }
    scope :default, -> { where(default: true) }

    def display_number
      raise NotImplementedError, "Please implement '#{display_number})' in your Payment Source: #{self.class.name}"
    end

    def actions
      %w{capture void credit}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      !payment.failed? && !payment.void?
    end

    # Indicates whether its possible to credit the payment.  Note that most gateways require that the
    # payment be settled first which generally happens within 12-24 hours of the transaction.
    def can_credit?(payment)
      payment.completed? && payment.credit_allowed > 0
    end

    def has_payment_profile?
      gateway_customer_profile_id.present?
    end

    # ActiveMerchant needs first_name/last_name because we pass it a Spree::CreditCard and it calls those methods on it.
    # Looking at the ActiveMerchant source code we should probably be calling #to_active_merchant before passing
    # the object to ActiveMerchant but this should do for now.
    def first_name
      name.to_s.split(/[[:space:]]/, 2)[0]
    end

    def last_name
      name.to_s.split(/[[:space:]]/, 2)[1]
    end
  end
end
