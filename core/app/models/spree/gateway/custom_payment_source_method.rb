module Spree
  class Gateway::CustomPaymentSourceMethod < Gateway
    def provider_class
      self.class
    end

    def payment_source_class
      Spree::PaymentSource
    end

    def confirmation_required?
      true
    end

    def payment_profiles_supported?
      true
    end

    def show_in_admin?
      false
    end

    def create_profile(payment)
      return if payment.source.gateway_customer.present?

      user = payment.source.user || payment.order.user
      return if user.blank?

      find_or_create_customer(user)
    end

    # simulate a 3rd party payment gateway api to fetch/or create a customer
    def find_or_create_customer(user)
      gateway_customers.find_or_create_by!(user: user, profile_id: "CUSTOMER-#{user.id}")
    end
  end
end
