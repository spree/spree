module Spree
  module PaymentGateway
    
    def authorize
      gateway = payment_gateway 
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      response = gateway.authorize(order.total * 100, @creditcard, gateway_options)
      gateway_error(:problem_authorizing_card) unless response.success?
      
      # create a transaction to reflect the authorization
      self.creditcard_txns << CreditcardTxn.new(
        :amount => order.total,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::AUTHORIZE
      )
      # TODO - email confirmation
    end

    def capture
      authorization = find_authorization
      gw = payment_gateway
      response = gw.capture(order.total * 100, authorization.response_code, minimal_gateway_options)
      gateway_error(:problem_authorizing_card) unless response.success?
      
      order.credit_card.txns << CreditcardTxn.new(
        :amount => order.total,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::CAPTURE
      )
      order.save
    end

    def void
      # TODO: Test with Authorize.net, etc.  Make sure its really voiding.
      authorization = find_authorization
      response = payment_gateway.void(authorization.response_code, minimal_gateway_options)
      gateway_error(:problem_voiding_card) unless response.success?
      creditcard.txns << CreditcardTxn.new(
        :amount => order.total,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::CAPTURE
      )
      save
    end
    
    def gateway_error(error_key, response)
      msg = "#{Globalite.loc(error_key)} ... #{response.params['message']}"
      logger.error(msg)
      raise SecurityError.new(msg)
    end
        
    def gateway_options
      options = {:billing_address => generate_address_hash(address), :shipping_address => generate_address_hash(order.address)}
      options.merge minimal_gateway_options
    end    
    
    # Generates an ActiveMerchant compatible address hash from one of Spree's address objects
    def generate_address_hash(address)
      {:name => address.full_name, :address1 => address.address1, :address2 => address.address2, :city => address.city,
       :state => address.state.abbr, :zip => address.zipcode, :country => address.country.iso, :phone => address.phone}
    end
    
    # Generates a minimal set of gateway options.  There appears to be some issues with passing in 
    # a billing address when authorizing/voiding a previously captured transaction.  So omits these 
    # options in this case since they aren't necessary.  
    def minimal_gateway_options
      {:email => order.user.email, 
       :customer => order.user.email, 
       :ip => order.ip_address, 
       :order_id => order.number,
       :shipping => order.ship_amount * 100,
       :tax => order.tax_amount * 100, 
       :subtotal => order.item_total * 100}  
    end
    
    # instantiates the selected gateway and configures with the options stored in the database
    def payment_gateway
      return Spree::BogusGateway.new if ENV['RAILS_ENV'] == "development"

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