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
        purchase(payment.amount.to_f, payment)
      else
        authorize(payment.amount.to_f, payment)
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

    def authorize(amount, payment)
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      payment_gateway = payment.payment_method
      check_environment(payment_gateway)

      response = payment_gateway.authorize((amount * 100).round, self, gateway_options(payment))
      record_log payment, response

      if response.success?
        payment.response_code = response.authorization
        payment.avs_response = response.avs_result['code']
        payment.pend
      else
        payment.failure
        gateway_error(response)
      end
    rescue ActiveMerchant::ConnectionError => e
      gateway_error e
    end

    def purchase(amount, payment)
      #combined Authorize and Capture that gets processed by the ActiveMerchant gateway as one single transaction.
      payment_gateway = payment.payment_method
      check_environment(payment_gateway)

      response = payment_gateway.purchase((amount * 100).round, self, gateway_options(payment))
      record_log payment, response

      if response.success?
        payment.response_code = response.authorization
        payment.avs_response = response.avs_result['code']
        payment.complete
      else
        payment.failure
        gateway_error(response)
      end
    rescue ActiveMerchant::ConnectionError => e
      gateway_error e
    end

    def capture(payment)
      return unless payment.pending?
      payment_gateway = payment.payment_method
      check_environment(payment_gateway)

      if payment_gateway.payment_profiles_supported?
        # Gateways supporting payment profiles will need access to creditcard object because this stores the payment profile information
        # so supply the authorization itself as well as the creditcard, rather than just the authorization code
        response = payment_gateway.capture(payment, self, minimal_gateway_options(payment, false))
      else
        # Standard ActiveMerchant capture usage
        response = payment_gateway.capture((payment.amount * 100).round, payment.response_code, minimal_gateway_options(payment, false))
      end

      record_log payment, response

      if response.success?
        payment.response_code = response.authorization
        payment.complete
      else
        payment.failure
        gateway_error(response)
      end
    rescue ActiveMerchant::ConnectionError => e
      gateway_error e
    end

    def void(payment)
      payment_gateway = payment.payment_method
      check_environment(payment_gateway)

      response = payment_gateway.void(payment.response_code, minimal_gateway_options(payment, false))
      record_log payment, response

      if response.success?
        payment.response_code = response.authorization
        payment.void
      else
        gateway_error(response)
      end
    rescue ActiveMerchant::ConnectionError => e
      gateway_error e
    end

    def credit(payment)
      payment_gateway = payment.payment_method
      check_environment(payment_gateway)

      amount = payment.credit_allowed >= payment.order.outstanding_balance.abs ? payment.order.outstanding_balance.abs : payment.credit_allowed.abs
      if payment_gateway.payment_profiles_supported?
        response = payment_gateway.credit((amount * 100).round, self, payment.response_code, minimal_gateway_options(payment, false))
      else
        response = payment_gateway.credit((amount * 100).round, payment.response_code, minimal_gateway_options(payment, false))
      end

      record_log payment, response

      if response.success?
        Payment.create({ :order => payment.order,
                         :source => payment,
                         :payment_method => payment.payment_method,
                         :amount => amount.abs * -1,
                         :response_code => response.authorization,
                         :state => 'completed' }, :without_protection => true)
      else
        gateway_error(response)
      end
    rescue ActiveMerchant::ConnectionError => e
      gateway_error e
    end

    def actions
      %w{capture void credit}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      payment.state == 'pending'
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      payment.state == 'void' ? false : true
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

    def record_log(payment, response)
      payment.log_entries.create({:details => response.to_yaml}, :without_protection => true)
    end

    def gateway_error(error)
      if error.is_a? ActiveMerchant::Billing::Response
        text = error.params['message'] || error.params['response_reason_text'] || error.message
      elsif error.is_a? ActiveMerchant::ConnectionError
        text = I18n.t(:unable_to_connect_to_gateway)
      else
        text = error.to_s
      end
      logger.error(I18n.t(:gateway_error))
      logger.error("  #{error.to_yaml}")
      raise Core::GatewayError.new(text)
    end

    def gateway_options(payment)
      options = { :billing_address  => generate_address_hash(payment.order.bill_address),
                  :shipping_address => generate_address_hash(payment.order.ship_address) }
      options.merge minimal_gateway_options(payment)
    end

    # Generates an ActiveMerchant compatible address hash from one of Spree's address objects
    def generate_address_hash(address)
      return {} if address.nil?
      { :name => address.full_name, :address1 => address.address1, :address2 => address.address2, :city => address.city,
        :state => address.state_text, :zip => address.zipcode, :country => address.country.iso, :phone => address.phone }
    end

    # Generates a minimal set of gateway options.  There appears to be some issues with passing in
    # a billing address when authorizing/voiding a previously captured transaction.  So omits these
    # options in this case since they aren't necessary.
    def minimal_gateway_options(payment, totals = true)

      options = { :email    => payment.order.email,
                  :customer => payment.order.email,
                  :ip       => payment.order.ip_address,
                  :order_id => payment.order.number }
      if totals
        options.merge!({ :shipping => payment.order.ship_total * 100,
                         :tax      => payment.order.tax_total * 100,
                         :subtotal => payment.order.item_total * 100 })
      end
      options
    end

    def spree_cc_type
      return 'visa' if Rails.env.development?
      cc_type
    end

    # Saftey check to make sure we're not accidentally performing operations on a live gateway.
    # Ex. When testing in staging environment with a copy of production data.
    def check_environment(gateway)
      return if gateway.environment == Rails.env
      message = I18n.t(:gateway_config_unavailable) + " - #{Rails.env}"
      raise Core::GatewayError.new(message)
    end
  end
end
