module Spree
  module PaymentGateway    
    def authorize(amount)
      gateway = payment_gateway       
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      response = gateway.authorize((amount * 100).to_i, self, gateway_options)      
      gateway_error(response) unless response.success?
      
      # create a creditcard_payment for the amount that was authorized
      creditcard_payment = checkout.order.creditcard_payments.create(:amount => 0, :creditcard => self)
      # create a transaction to reflect the authorization
      creditcard_payment.creditcard_txns << CreditcardTxn.new(
        :amount => amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::AUTHORIZE
      )
    end

    def capture(authorization)
      gw = payment_gateway
      response = gw.capture((authorization.amount * 100).to_i, authorization.response_code, minimal_gateway_options)
      gateway_error(response) unless response.success?          
      creditcard_payment = authorization.creditcard_payment
      # create a transaction to reflect the capture
      creditcard_payment.creditcard_txns << CreditcardTxn.new(
        :amount => authorization.amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::CAPTURE
      )
    end

    def purchase(amount)
      #combined Authorize and Capture that gets processed by the ActiveMerchant gateway as one single transaction.
      gateway = payment_gateway 
      response = gateway.purchase((amount * 100).to_i, self, gateway_options) 
      gateway_error(response) unless response.success?
      
      
      # create a creditcard_payment for the amount that was purchased
      creditcard_payment = checkout.order.creditcard_payments.create(:amount => amount, :creditcard => self)
      # create a transaction to reflect the purchase
      creditcard_payment.creditcard_txns << CreditcardTxn.new(
        :amount => amount,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::PURCHASE
      )
    end

    def void
=begin
      authorization = find_authorization
      response = payment_gateway.void(authorization.response_code, minimal_gateway_options)
      gateway_error(response) unless response.success?
      self.creditcard_txns.create(:amount => order.total, :response_code => response.authorization, :txn_type => CreditcardTxn::TxnType::CAPTURE)
=end
    end
    
    def gateway_error(response)
      text = response.params['message'] || 
             response.params['response_reason_text'] ||
             response.message
      msg = "#{I18n.t('gateway_error')} ... #{text}"
      logger.error(msg)
      raise Spree::GatewayError.new(msg)
    end
        
    def gateway_options
      options = {:billing_address => generate_address_hash(checkout.bill_address), 
                 :shipping_address => generate_address_hash(checkout.shipment.address)}
      options.merge minimal_gateway_options
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
    def minimal_gateway_options
      {:email => checkout.email, 
       :customer => checkout.email, 
       :ip => checkout.ip_address, 
       :order_id => checkout.order.number,
       :shipping => checkout.order.ship_total * 100,
       :tax => checkout.order.tax_total * 100, 
       :subtotal => checkout.order.item_total * 100}  
    end
    
    def spree_cc_type
      return "visa" if ENV['RAILS_ENV'] == "development" and Spree::Gateway::Config[:use_bogus]
      self.class.type?(number)
    end

    # instantiates the selected gateway and configures with the options stored in the database
    def payment_gateway
      return Spree::BogusGateway.new if ENV['RAILS_ENV'] == "development" and Spree::Gateway::Config[:use_bogus]

      # retrieve gateway configuration from the database
      gateway_config = GatewayConfiguration.find :first
      config_options = {}
      gateway_config.gateway_option_values.each do |option_value|
        key = option_value.gateway_option.name.to_sym
        config_options[key] = option_value.value
      end
      gateway = gateway_config.gateway.clazz.constantize.new(config_options)

      return gateway
    end  
  end
end
