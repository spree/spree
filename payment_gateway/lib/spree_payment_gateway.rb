require 'spree_core'
require 'active_merchant'

module SpreePaymentGateway
  class Engine < Rails::Engine
    def self.activate
      lambda{
        # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
        Creditcard.class_eval do
          # add gateway methods to the creditcard so we can authorize, capture, etc.
          include SpreePaymentGateway::CardMethods
        end
      }
    end
    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &self.activate
  end
end

ActiveSupport.on_load(:after_initialize) do
  # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
  Creditcard.class_eval do
    # add gateway methods to the creditcard so we can authorize, capture, etc.
    include SpreePaymentGateway::CardMethods
  end

  silence_warnings { require 'active_merchant/billing/authorize_net_cim' }

  #register all payment methods (unless we're in middle of rake task since migrations cannot be run for this first time without this check)
  if File.basename( $0 ) != "rake"
    [
      Gateway::Bogus,
      Gateway::AuthorizeNet,
      Gateway::AuthorizeNetCim,
      Gateway::Eway,
      Gateway::Linkpoint,
      Gateway::PayPal,
      Gateway::SagePay,
      Gateway::Beanstream,
      PaymentMethod::Check
    ].each{|gw|
      begin
        gw.register
      rescue Exception => e
        $stderr.puts "Error registering gateway #{gw}: #{e}"
      end
    }
  end
end