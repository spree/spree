module SpreeStripe
  class UpdateCustomerJob < BaseJob
    def perform(customer_id)
      customer = Spree.customer_class.find_by(id: customer_id)
      return if customer.blank?

      SpreeStripe::UpdateCustomer.new.call(customer: customer)
    end
  end
end
