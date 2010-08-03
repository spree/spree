require "spree_payment_gateway"

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