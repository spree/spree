module SpreeStripe
  # Registers a storefront domain with Stripe. Apple Pay and Google Pay only
  # offer themselves on domains Stripe has verified, so quick checkout depends
  # on this having run.
  class RegisterDomain
    # @param model [Spree::Store, Spree::CustomDomain]
    # @return [Stripe::PaymentMethodDomain, nil]
    def call(model:)
      gateway = model.is_a?(Spree::Store) ? model.stripe_gateway : model.store.stripe_gateway
      return if gateway.blank?

      payment_method_domain = gateway.send_request do |opts|
        Stripe::PaymentMethodDomain.create({ domain_name: model.url }, opts)
      end

      attributes_to_update = { stripe_apple_pay_domain_id: payment_method_domain.id }

      # A custom domain on a subdomain needs its apex registered too, or Apple Pay
      # refuses to render there.
      tld_length = model.url.split('.').length
      if tld_length > 2 && defined?(Spree::CustomDomain) && model.is_a?(Spree::CustomDomain)
        top_level_domain_name = model.url.split('.').last(tld_length - 1).join('.')
        top_level_domain = gateway.send_request do |opts|
          Stripe::PaymentMethodDomain.create({ domain_name: top_level_domain_name }, opts)
        end
        attributes_to_update[:stripe_top_level_domain_id] = top_level_domain.id
      end

      model.update!(**attributes_to_update)

      payment_method_domain
    end
  end
end
