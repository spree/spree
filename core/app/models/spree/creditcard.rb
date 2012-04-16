module Spree
  class Creditcard < ActiveRecord::Base
    has_many :payments, :as => :source

    before_save :set_last_digits
    after_validation :set_card_type

    attr_accessor :number, :verification_value

    validates :month, :year, :numericality => { :only_integer => true }
    validates :number, :presence => true, :unless => :has_payment_profile?, :on => :create
    validates :verification_value, :presence => true, :unless => :has_payment_profile?, :on => :create

    attr_accessible :first_name, :last_name, :number, :verification_value, :year,
                    :month, :gateway_customer_profile_id

    def process!(payment)
      if Spree::Config[:auto_capture]
        payment.purchase!
      else
        payment.authorize!
      end
    end

    def set_last_digits
      number.to_s.gsub!(/\s/,'') unless number.nil?
      verification_value.to_s.gsub!(/\s/,'') unless number.nil?
      self.last_digits ||= number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1)
    end

    # cheap hack to get to the type? method from deep within ActiveMerchant without stomping on
    # potentially existing methods in CreditCard
    class CardDetector
      class << self
        include ActiveMerchant::Billing::CreditCardMethods::ClassMethods
      end
    end

    # sets self.cc_type while we still have the card number
    def set_card_type
      self.cc_type ||= CardDetector.type?(number)
    end

    def name?
      first_name? && last_name?
    end

    def first_name?
      first_name.present?
    end

    def last_name?
      last_name.present?
    end

    def name
      "#{first_name} #{last_name}"
    end

    def verification_value?
      verification_value.present?
    end

    # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
    def display_number
      "XXXX-XXXX-XXXX-#{last_digits}"
    end

    # needed for some of the ActiveMerchant gateways (eg. SagePay)
    def brand
      cc_type
    end

    scope :with_payment_profile, where('gateway_customer_profile_id IS NOT NULL')

    def actions
      %w{capture void credit}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.state == 'pending'
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      payment.state != 'void'
    end

    # Indicates whether its possible to credit the payment.  Note that most gateways require that the
    # payment be settled first which generally happens within 12-24 hours of the transaction.
    def can_credit?(payment)
      return false unless payment.state == 'completed'
      return false unless payment.order.payment_state == 'credit_owed'
      payment.credit_allowed > 0
    end

    def has_payment_profile?
      gateway_customer_profile_id.present?
    end

    def spree_cc_type
      return 'visa' if Rails.env.development?
      cc_type
    end
  end
end
