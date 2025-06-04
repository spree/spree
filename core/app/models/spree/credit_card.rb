module Spree
  class CreditCard < Spree.base_class
    include ActiveMerchant::Billing::CreditCardMethods
    include Spree::Metadata
    include Spree::PaymentSourceConcern

    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end
    if defined?(Spree::Security::CreditCards)
      include Spree::Security::CreditCards
    end

    acts_as_paranoid

    belongs_to :payment_method
    belongs_to :user, class_name: Spree.user_class.to_s, foreign_key: 'user_id', optional: true
    belongs_to :gateway_customer, class_name: 'Spree::GatewayCustomer', optional: true

    has_many :payments, as: :source

    before_save :set_last_digits

    after_save :ensure_one_default

    # As of rails 4.2 string columns always return strings, we can override it on model level.
    attribute :month, ActiveRecord::Type::Integer.new
    attribute :year,  ActiveRecord::Type::Integer.new

    attr_reader :number, :verification_value
    attr_accessor :encrypted_data,
                  :imported,
                  :manual_entry

    with_options if: :require_card_numbers?, on: :create do
      validates :month, :year, numericality: { only_integer: true }
      validates :number, :verification_value, presence: true, unless: :imported
      validates :name, presence: true
    end

    scope :with_payment_profile, -> { where.not(gateway_customer_profile_id: nil) }
    scope :default, -> { where(default: true) }
    scope :not_expired, lambda {
      where('CAST(spree_credit_cards.year AS DECIMAL) > ?', Time.current.year).
        or(where('CAST(spree_credit_cards.year AS DECIMAL) = ?', Time.current.year).
           where('CAST(spree_credit_cards.month AS DECIMAL) >= ?', Time.current.month))
    }
    scope :not_removed, -> { where(deleted_at: nil) }

    # needed for some of the ActiveMerchant gateways (eg. SagePay)
    alias_attribute :brand, :cc_type

    # ActiveMerchant::Billing::CreditCard added this accessor used by some gateways.
    # More info: https://github.com/spree/spree/issues/6209
    #
    # Returns or sets the track data for the card
    #
    # @return [String]
    attr_accessor :track_data

    CARD_TYPES = {
      visa: /^4\d{12}(\d{3})?(\d{3})?$/,
      master: /^(5[1-5]\d{4}|677189|222[1-9]\d{2}|22[3-9]\d{3}|2[3-6]\d{4}|27[01]\d{3}|2720\d{2})\d{10}$/,
      discover: /^(6011|65\d{2}|64[4-9]\d)\d{12}|(62\d{14})$/,
      american_express: /^3[47]\d{13}$/,
      diners_club: /^3(0[0-5]|[68]\d)\d{11}$/,
      jcb: /^35(28|29|[3-8]\d)\d{12}$/,
      switch: /^6759\d{12}(\d{2,3})?$/,
      solo: /^6767\d{12}(\d{2,3})?$/,
      dankort: /^5019\d{12}$/,
      maestro: /^(5[06-8]|6\d)\d{10,17}$/,
      forbrugsforeningen: /^600722\d{10}$/,
      laser: /^(6304|6706|6709|6771(?!89))\d{8}(\d{4}|\d{6,7})?$/
    }.freeze

    def expiry=(expiry)
      return unless expiry.present?

      self[:month], self[:year] =
        if expiry =~ /\d{2}\s?\/\s?\d{2,4}/ # will match mm/yy and mm / yyyy
          expiry.delete(' ').split('/')
        elsif match = expiry.match(/(\d{2})(\d{2,4})/) # will match mmyy and mmyyyy
          [match[1], match[2]]
        end
      if self[:year]
        self[:year] = "20#{self[:year]}" if (self[:year] / 100).zero?
        self[:year] = self[:year].to_i
      end
      self[:month] = self[:month].to_i if self[:month]
    end

    def number=(num)
      @number = begin
                  num.gsub(/[^0-9]/, '')
                rescue StandardError
                  nil
                end
    end

    # cc_type is set by jquery.payment, which helpfully provides different
    # types from Active Merchant. Converting them is necessary.
    def cc_type=(type)
      self[:cc_type] = case type
                       when 'mastercard', 'maestro' then 'master'
                      when 'amex' then 'american_express'
                       when 'dinersclub' then 'diners_club'
                       when '' then try_type_from_number
                       else type
                       end
    end

    alias_method :brand=, :cc_type=

    def verification_value=(value)
      @verification_value = value.to_s.gsub(/\s/, '')
    end

    def set_last_digits
      self.last_digits ||= number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1)
    end

    def try_type_from_number
      numbers = number.delete(' ') if number
      CARD_TYPES.find { |type, pattern| return type.to_s if numbers =~ pattern }.to_s
    end

    def verification_value?
      verification_value.present?
    end

    # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
    def display_number
      "XXXX-XXXX-XXXX-#{last_digits}"
    end

    def display_brand
      brand.present? ? brand.upcase : Spree.t(:no_cc_type)
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

    def to_active_merchant
      ActiveMerchant::Billing::CreditCard.new(
        number: number,
        month: month,
        year: year,
        verification_value: verification_value,
        first_name: first_name,
        last_name: last_name
      )
    end

    def self.json_api_permitted_attributes
      [
        'number', 'month', 'year', 'expiry', 'verification_value', 'first_name', 'last_name',
        'cc_type', 'gateway_customer_profile_id', 'gateway_payment_profile_id', 'last_digits',
        'name', 'encrypted_data', 'address_id', 'created_at', 'updated_at', 'user_id',
        'payment_method_id', 'default', 'deleted_at'
      ]
    end

    private

    def require_card_numbers?
      !encrypted_data.present? && !has_payment_profile?
    end

    def ensure_one_default
      if user_id && default
        CreditCard.where(default: true, user_id: user_id).where.not(id: id).
          update_all(default: false)
      end
    end
  end
end
