require "spree_payment_gateway"

module SpreePaymentGateway
  class Engine < Rails::Engine
    config.autoload_paths += %W(#{config.root}/lib)
  end
end