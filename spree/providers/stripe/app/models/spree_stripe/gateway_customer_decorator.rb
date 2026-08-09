module SpreeStripe
  module GatewayCustomerDecorator
    def self.prepended(base)
      base.scope :stripe, lambda {
        joins(:payment_method).where(Spree::PaymentMethod.table_name => { type: SpreeStripe::Gateway.to_s })
      }
    end
  end
end

Spree::GatewayCustomer.prepend(SpreeStripe::GatewayCustomerDecorator)
