module SpreeStripe
  module StoreDecorator
    def self.prepended(base)
      base.store_accessor :metadata, :stripe_apple_pay_domain_id
      base.store_accessor :metadata, :stripe_top_level_domain_id

      base.after_commit :register_stripe_domain, on: :update, if: -> { code_previously_changed? }
    end

    # @return [SpreeStripe::Gateway, nil]
    def stripe_gateway
      @stripe_gateway ||= payment_methods.stripe.active.last
    end

    private

    def register_stripe_domain
      return if stripe_gateway.blank?

      SpreeStripe::RegisterDomainJob.perform_later(id)
    end
  end
end

Spree::Store.prepend(SpreeStripe::StoreDecorator)
