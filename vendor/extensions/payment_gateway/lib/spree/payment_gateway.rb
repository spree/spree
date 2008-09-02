module Spree
  module PaymentGateway
    
    def authorize_card
      gateway = payment_gateway 
      # ActiveMerchant is configured to use cents so we need to multiply order total by 100
      response = gateway.authorize(@order.total * 100, @creditcard, Order.gateway_options(order))
      unless response.success?
        msg = "#{Globalize.localize(:problem_authorizing_card)} ... #{response.params['message']}"
        logger.error(msg)
        raise msg
      end
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