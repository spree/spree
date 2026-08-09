module SpreeStripe
  # Pushes Spree-side customer changes (name, email, address) to Stripe.
  class UpdateCustomer
    # @param customer [Spree::Customer]
    def call(customer:)
      gateway_customers = customer.gateway_customers.stripe
      return if gateway_customers.empty?

      gateway_customers.each do |gateway_customer|
        gateway_customer.payment_method.update_customer(customer: customer)
      end
    end
  end
end
