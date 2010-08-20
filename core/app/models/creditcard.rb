class Creditcard < ActiveRecord::Base
  has_many :payments, :as => :source

  before_save :set_last_digits

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




  #RAILS3 TODO
  # scope :with_payment_profile, where("gateway_customer_profile_id IS NOT NULL")

  def authorize(amount, payment)
    # ActiveMerchant is configured to use cents so we need to multiply order total by 100
    response = payment_gateway.authorize((amount * 100).round, self, gateway_options(payment))
    if response.success?
      payment.response_code = response.response_code
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
    if response.success?
      payment.response_code = response.response_code
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
    return unless transaction = authorization(payment)
    if payment_gateway.payment_profiles_supported?
      # Gateways supporting payment profiles will need access to creditcard object because this stores the payment profile information
      # so supply the authorization itself as well as the creditcard, rather than just the authorization code
      response = payment_gateway.capture(transaction, self, minimal_gateway_options(payment))
    else
      # Standard ActiveMerchant capture usage
      response = payment_gateway.capture((transaction.amount * 100).round, transaction.response_code, minimal_gateway_options(payment))
    end
    gateway_error(response) unless response.success?
    payment.complete
  rescue ActiveMerchant::ConnectionError => e
    gateway_error I18n.t(:unable_to_connect_to_gateway)
  end

  def void(payment)
    return unless transaction = purchase_or_authorize_transaction_for_payment(payment)

    response = payment_gateway.void(transaction.response_code, self, minimal_gateway_options(payment))
    gateway_error(response) unless response.success?

    # create a transaction to reflect the void
    save
    payment.void
  end

  def credit(payment, amount=nil)
    return unless transaction = purchase_or_authorize_transaction_for_payment(payment)

    amount ||= payment.order.outstanding_credit

    if payment_gateway.payment_profiles_supported?
      response = payment_gateway.credit((amount * 100).round, self, transaction.response_code, minimal_gateway_options(payment))
    else
      response = payment_gateway.credit((amount * 100).round, transaction.response_code, minimal_gateway_options(payment))
    end
    gateway_error(response) unless response.success?

    # create a transaction to reflect the purchase
    save
    payment.update_attribute(:amount, payment.amount - amount)
  rescue ActiveMerchant::ConnectionError => e
    gateway_error I18n.t(:unable_to_connect_to_gateway)
  end

  # find the transaction associated with the original authorization/capture
  def authorization(payment)
    payment.txns.find(:first,
              :conditions => ["type = 'CreditcardTxn' AND txn_type = ? AND response_code IS NOT NULL", CreditcardTxn::TxnType::AUTHORIZE.to_s],
              :order => 'created_at DESC')
  end

  # find a transaction that can be used to void or credit
  def purchase_or_authorize_transaction_for_payment(payment)
    payment.txns.detect {|txn| [CreditcardTxn::TxnType::AUTHORIZE, CreditcardTxn::TxnType::PURCHASE].include?(txn.txn_type) and txn.response_code.present?}
  end

  def actions
    %w{capture void credit}
  end

  def can_capture?(payment)
    authorization(payment).present? &&
    has_no_transaction_of_types?(payment, CreditcardTxn::TxnType::PURCHASE, CreditcardTxn::TxnType::CAPTURE, CreditcardTxn::TxnType::VOID)
  end

  def can_void?(payment)
    has_transaction_of_types?(payment, CreditcardTxn::TxnType::AUTHORIZE, CreditcardTxn::TxnType::PURCHASE, CreditcardTxn::TxnType::CAPTURE) &&
    has_no_transaction_of_types?(payment, CreditcardTxn::TxnType::VOID)
  end

  # Can only refund a captured transaction but if transaction hasn't been cleared by merchant, refund may still fail
  def can_credit?(payment)
    has_transaction_of_types?(payment, CreditcardTxn::TxnType::PURCHASE, CreditcardTxn::TxnType::CAPTURE) &&
    has_no_transaction_of_types?(payment, CreditcardTxn::TxnType::VOID) and payment.order.outstanding_credit?
  end

  def has_payment_profile?
    gateway_customer_profile_id.present?
  end

  def gateway_error(error)
    if error.is_a? ActiveMerchant::Billing::Response
      text = error.params['message'] ||
             error.params['response_reason_text'] ||
             error.message
    else
      text = error.to_s
    end

    logger.error(I18n.t('gateway_error'))
    logger.error("  #{error.to_yaml}")
    raise Spree::GatewayError.new(text)
  end

  def gateway_options(payment)
    options = {:billing_address  => generate_address_hash(payment.order.bill_address),
               :shipping_address => generate_address_hash(payment.order.shipment.address)}
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

  private

    def has_transaction_of_types?(payment, *types)
      (payment.txns.map(&:txn_type) & types).any?
    end

    def has_no_transaction_of_types?(payment, *types)
      (payment.txns.map(&:txn_type) & types).none?
    end

    #RAILS 3 TODO
    # # Override default behavior of Rails attr_readonly so that its never written to the database (not even on create)
    # def attributes_with_quotes(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
    #   attributes_with_quotes_default(include_primary_key, false, attribute_names)
    # end

    def remove_readonly_attributes(attributes)
      if self.class.readonly_attributes.present?
        attributes.delete_if { |key, value| self.class.readonly_attributes.include?(key.gsub(/\(.+/,"")) }
      end
      # extra logic for sanitizing the number and verification value based on preferences
      attributes.delete_if { |key, value| key == "number" and !Spree::Config[:store_cc] }
      attributes.delete_if { |key, value| key == "verification_value" and !Spree::Config[:store_cvv] }
    end

end
