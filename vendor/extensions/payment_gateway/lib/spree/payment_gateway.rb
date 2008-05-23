module Spree
  module PaymentGateway
    # Instantiates the selected PAYMENT_GATEWAY and initializes with GATEWAY_OPTIONS (configured in environment.rb)
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