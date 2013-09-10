module Spree
  class CreditCard < ActiveRecord::Base
    has_many :payments, as: :source

    before_save :set_last_digits

    attr_accessor :number, :verification_value

    validates :month, :year, numericality: { only_integer: true }
    validates :number, presence: true, unless: :has_payment_profile?, on: :create
    validates :verification_value, presence: true, unless: :has_payment_profile?, on: :create
    validate :expiry_not_in_the_past

    scope :with_payment_profile, -> { where('gateway_customer_profile_id IS NOT NULL') }

    def expiry=(expiry)
      self[:month], self[:year] = expiry.split(" / ")
      self[:year] = "20" + self[:year]
    end

    def number=(num)
      @number = num.gsub(/[^0-9]/, '') rescue nil
    end

    def set_last_digits
      number.to_s.gsub!(/\s/,'')
      verification_value.to_s.gsub!(/\s/,'')
      self.last_digits ||= number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1)
    end

    def name?
      first_name? && last_name?
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
    alias :brand, :cc_type

    def actions
      %w{capture void credit}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      !payment.void?
    end

    # Indicates whether its possible to credit the payment.  Note that most gateways require that the
    # payment be settled first which generally happens within 12-24 hours of the transaction.
    def can_credit?(payment)
      return false unless payment.completed?
      return false unless payment.order.payment_state == 'credit_owed'
      payment.credit_allowed > 0
    end

    def has_payment_profile?
      gateway_customer_profile_id.present?
    end

    def to_active_merchant
      ActiveMerchant::Billing::CreditCard.new(
        :number => number,
        :month => month,
        :year => year,
        :verification_value => verification_value,
        :first_name => first_name,
        :last_name => last_name
      )
    end

    private

    def expiry_not_in_the_past
      if year.present? && month.present?
        time = "#{year}-#{month}-1".to_time
        if time < Time.zone.now.to_time.beginning_of_month
          errors.add(:base, :card_expired)
        end
      end
    end
  end
end
