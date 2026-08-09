module SpreeStripe
  module CustomerDecorator
    def self.prepended(base)
      base.after_update :update_stripe_customer, if: :should_update_stripe_customer?
    end

    def update_stripe_customer
      SpreeStripe::UpdateCustomerJob.perform_later(id)
    end

    private

    def should_update_stripe_customer?
      ship_address_previously_changed? || bill_address_previously_changed? ||
        first_name_previously_changed? || last_name_previously_changed? ||
        email_previously_changed?
    end
  end
end

Spree.customer_class.prepend(SpreeStripe::CustomerDecorator) if Spree.customer_class.present?
