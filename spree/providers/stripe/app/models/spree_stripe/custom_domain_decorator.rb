module SpreeStripe
  module CustomDomainDecorator
    def self.prepended(base)
      base.store_accessor :metadata, :stripe_apple_pay_domain_id
      base.store_accessor :metadata, :stripe_top_level_domain_id

      base.after_create :register_stripe_domain
    end

    def register_stripe_domain
      return if store.stripe_gateway.blank?

      SpreeStripe::RegisterDomainJob.perform_later(id, 'custom_domain')
    end
  end
end

Spree::CustomDomain.prepend(SpreeStripe::CustomDomainDecorator) if defined?(Spree::CustomDomain)
