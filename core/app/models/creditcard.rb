class Creditcard < ActiveRecord::Base
  has_many :payments, :as => :source

  before_save :set_last_digits

  attr_accessor :number, :verification_value

  validates :month, :year, :numericality => { :only_integer => true }
  validates :number, :presence => true, :unless => :has_payment_profile?, :on => :create
  validates :verification_value, :presence => true, :unless => :has_payment_profile?, :on => :create

  def process!(payment)
    begin
      if Spree::Config[:auto_capture]
        purchase(payment.amount.to_f, payment)
      else
        authorize(payment.amount.to_f, payment)
      end
    end
  end

  def set_last_digits
    number.to_s.gsub!(/\s/,'') unless number.nil?
    verification_value.to_s.gsub!(/\s/,'') unless number.nil?
    self.last_digits ||= number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1)
  end

  def name?
    first_name? && last_name?
  end

  def first_name?
    !self.first_name.blank?
  end

  def last_name?
    !self.last_name.blank?
  end

  def name
    "#{self.first_name} #{self.last_name}"
  end

  def verification_value?
    !verification_value.blank?
  end

  # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
  def display_number
   "XXXX-XXXX-XXXX-#{last_digits}"
  end

  #RAILS 3 TODO
  #alias :attributes_with_quotes_default :attributes_with_quotes


  # needed for some of the ActiveMerchant gateways (eg. SagePay)
  def brand
    cc_type
  end

  scope :with_payment_profile, where("gateway_customer_profile_id IS NOT NULL")

  def authorize(amount, payment)
    # ActiveMerchant is configured to use cents so we need to multiply order total by 100
    response = payment_gateway.authorize((amount * 100).round, self, gateway_options(payment))
    record_log payment, response

    if response.success?
      payment.response_code = response.authorization
      payment.avs_response = response.avs_result['code']
      payment.pend
    else
      payment.fail
      gateway_error(response)
    end
  rescue ActiveMerchant::ConnectionError => e
    gateway_error I18n.t(:unable_to_connect_to_gateway)
  end

  def purchase(amount, payment)
    #combined Authorize and Capture that gets processed by the ActiveMerchant gateway as one single transaction.
    response = payment_gateway.purchase((amount * 100).round, self, gateway_options(payment))
    record_log payment, response

    if response.success?
      payment.response_code = response.authorization
      payment.avs_response = response.avs_result['code']
      payment.complete
    else
      payment.fail
      gateway_error(response) unless response.success?
    end
  rescue ActiveMerchant::ConnectionError => e
    gateway_error t(:unable_to_connect_to_gateway)
  end

  def capture(payment)
    return unless payment.pending?
    if payment_gateway.payment_profiles_supported?
      # Gateways supporting payment profiles will need access to creditcard object because this stores the payment profile information
      # so supply the authorization itself as well as the creditcard, rather than just the authorization code
      response = payment_gateway.capture(payment, self, minimal_gateway_options(payment))
    else
      # Standard ActiveMerchant capture usage
      response = payment_gateway.capture((payment.amount * 100).round, payment.response_code, minimal_gateway_options(payment))
    end

    record_log payment, response

    if response.success?
      payment.response_code = response.authorization
      payment.complete
    else
      payment.fail
      gateway_error(response)
    end
  rescue ActiveMerchant::ConnectionError => e
    gateway_error I18n.t(:unable_to_connect_to_gateway)
  end

  def void(payment)
    response = payment_gateway.void(payment.response_code, self, minimal_gateway_options(payment))
    record_log payment, response

    if response.success?
      payment.response_code = response.authorization
      payment.void
    else
      gateway_error(response)
    end
  rescue ActiveMerchant::ConnectionError => e
    gateway_error I18n.t(:unable_to_connect_to_gateway)
  end

  def credit(payment)
    amount = payment.credit_allowed >= payment.order.outstanding_balance.abs ? payment.order.outstanding_balance.abs : payment.credit_allowed.abs

    if payment_gateway.payment_profiles_supported?
      response = payment_gateway.credit((amount * 100).round, self, payment.response_code, minimal_gateway_options(payment))
    else
      response = payment_gateway.credit((amount * 100).round, payment.response_code, minimal_gateway_options(payment))
    end

    record_log payment, response

    if response.success?
      Payment.create(:order => payment.order,
                    :source => payment,
                    :payment_method => payment.payment_method,
                    :amount => amount.abs * -1,
                    :response_code => response.authorization,
                    :state => 'completed')
    else
      gateway_error(response)
    end
  rescue ActiveMerchant::ConnectionError => e
    gateway_error I18n.t(:unable_to_connect_to_gateway)
  end




  def actions
    %w{capture void credit}
  end

  # Indicates whether its possible to capture the payment
  def can_capture?(payment)
    payment.state == "pending"
  end

  # Indicates whether its possible to void the payment.  Most gateways require that the payment has not been
  # settled yet when performing a void (which generally happens within 12-24 hours of the transaction.)  For
  # this reason, the default behavior of Spree is to only allow void operations within the first 12 hours of
  # the payment creation time.
  def can_void?(payment)
    return false unless (Time.now - 12.hours) < payment.created_at
    %w{completed pending}.include? payment.state
  end

  # Indicates whether its possible to credit the payment.  Most gateways require that the payment be settled
  # first which generally happens within 12-24 hours of the transaction.  For this reason, the default
  # behavior of Spree is to disallow credit operations until the payment is at least 12 hours old.
  def can_credit?(payment)
    return false unless (Time.now - 12.hours) > payment.created_at
    return false unless payment.state == "completed"
    return false unless payment.order.payment_state == "credit_owed"
    payment.credit_allowed > 0
  end

  def has_payment_profile?
    gateway_customer_profile_id.present?
  end

  def record_log(payment, response)
    payment.log_entries.create(:details => response.to_yaml)
  end

  def gateway_error(error)
    if error.is_a? ActiveMerchant::Billing::Response
      text = error.params['message'] || error.params['response_reason_text'] || error.message
    else
      text = error.to_s
    end
    logger.error(I18n.t('gateway_error'))
    logger.error("  #{error.to_yaml}")
    raise Spree::GatewayError.new(text)
  end

  def gateway_options(payment)
    options = {:billing_address  => generate_address_hash(payment.order.bill_address),
               :shipping_address => generate_address_hash(payment.order.ship_address)}
    options.merge minimal_gateway_options(payment)
  end

  # Generates an ActiveMerchant compatible address hash from one of Spree's address objects
  def generate_address_hash(address)
    return {} if address.nil?
    {:name => address.full_name, :address1 => address.address1, :address2 => address.address2, :city => address.city,
     :state => address.state_text, :zip => address.zipcode, :country => address.country.iso, :phone => address.phone}
  end

  # Generates a minimal set of gateway options.  There appears to be some issues with passing in
  # a billing address when authorizing/voiding a previously captured transaction.  So omits these
  # options in this case since they aren't necessary.
  def minimal_gateway_options(payment)
    {:email    => payment.order.email,
     :customer => payment.order.email,
     :ip       => payment.order.ip_address,
     :order_id => payment.order.number,
     :shipping => payment.order.ship_total * 100,
     :tax      => payment.order.tax_total * 100,
     :subtotal => payment.order.item_total * 100}
  end

  def spree_cc_type
    return "visa" if ENV['RAILS_ENV'] == "development"
    self.class.type?(number)
  end

  def payment_gateway
    @payment_gateway ||= Gateway.current
  end

end
