module Spree
  module PaymentGateway    
    
    def self.included(base)
      base.named_scope :with_payment_profile, :conditions => "gateway_customer_profile_id IS NOT NULL"
    end
    
    def authorize(amount, payment)
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      response = payment_gateway.authorize((amount * 100).round, self, gateway_options(payment))      
      gateway_error_from_response(response) unless response.success?
      
      # create a transaction to reflect the authorization
      save
      payment.txns << CreditcardTxn.create(
        :amount => amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::AUTHORIZE,
        :avs_response => response.avs_result['code']
      )
    rescue ActiveMerchant::ConnectionError => e
      gateway_error I18n.t(:unable_to_connect_to_gateway)      
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
      gateway_error_from_response(response) unless response.success?          

      # create a transaction to reflect the capture
      save
      payment.txns << CreditcardTxn.create(
        :amount => transaction.amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::CAPTURE
      )
      payment.finalize!
    rescue ActiveMerchant::ConnectionError => e
      gateway_error I18n.t(:unable_to_connect_to_gateway)      
    end

    def purchase(amount, payment)
      #combined Authorize and Capture that gets processed by the ActiveMerchant gateway as one single transaction.
      response = payment_gateway.purchase((amount * 100).round, self, gateway_options(payment)) 
      
      gateway_error_from_response(response) unless response.success?

      # create a transaction to reflect the purchase
      save
      payment.txns << CreditcardTxn.create(
        :amount => amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::PURCHASE,
        :avs_response => response.avs_result['code']
      )
    rescue ActiveMerchant::ConnectionError => e
      gateway_error t(:unable_to_connect_to_gateway)
    end
    
    def void(payment)
      return unless transaction = purchase_or_authorize_transaction_for_payment(payment)

      response = payment_gateway.void(transaction.response_code, self, minimal_gateway_options(payment))
      gateway_error_from_response(response) unless response.success?

      # create a transaction to reflect the void
      save
      payment.txns << CreditcardTxn.create(
        :amount => -transaction.amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::VOID
      )
      payment.update_attribute(:amount, 0.00)
      payment.order.update_totals!
      payment.finalize!
    end

    def credit(payment, amount=nil)      
      return unless transaction = purchase_or_authorize_transaction_for_payment(payment)

      amount ||= payment.order.outstanding_credit
      
      if payment_gateway.payment_profiles_supported?
        response = payment_gateway.credit((amount * 100).round, self, transaction.response_code, minimal_gateway_options(payment))
      else
        response = payment_gateway.credit((amount * 100).round, transaction.response_code, minimal_gateway_options(payment))
      end
      gateway_error_from_response(response) unless response.success?

      # create a transaction to reflect the purchase
      save
      payment.txns << CreditcardTxn.create(
        :amount => -amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::CREDIT
      )
      payment.update_attribute(:amount, payment.amount - amount)
      payment.order.update_totals!
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
      has_no_transaction_of_types?(payment, CreditcardTxn::TxnType::VOID) and payment.order.credit_owed?
    end

    def has_payment_profile?
      gateway_customer_profile_id.present?
    end


    
    def gateway_error_from_response(response)
      text = response.params['message'] || 
             response.params['response_reason_text'] ||
             response.message
      gateway_error(text)
    end
    
    def gateway_error(text)
      msg = "#{I18n.t('gateway_error')} ... #{text}"
      logger.error(msg)
      raise Spree::GatewayError.new(msg)
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
    
    # TODO: Want to do this after_save but there is a possible danger of infinite loop which number_changed? check is intended to prevent.
    # Removed the check to number_changed? and relying on the !has_payment_profile? to not re-create if we have a profile
    def create_payment_profile
      return unless payment_gateway.payment_profiles_supported? and number and !has_payment_profile?
      payment_gateway.create_profile(self, {})
    rescue ActiveMerchant::ConnectionError => e
      gateway_error I18n.t(:unable_to_connect_to_gateway)
    end

    private

      def has_transaction_of_types?(payment, *types)
        (payment.txns.map(&:txn_type) & types).any?
      end

      def has_no_transaction_of_types?(payment, *types)
        (payment.txns.map(&:txn_type) & types).none?
      end
  end
end
