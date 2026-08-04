module Spree
  module Returns
    # The default return-eligibility rule: a time window, measured from order
    # completion, configured per market.
    #
    # Registered by core on `returns.create.validate` and
    # `exchanges.create.validate`. A store that wants different rules —
    # final-sale categories, per-customer-group windows, restocking fees —
    # unregisters this and registers its own handler:
    #
    #   Spree.hooks.unregister('returns.create.validate',
    #                          'Spree::Returns::EligibilityValidator')
    #   Spree.hooks.register('returns.create.validate', 'MyStore::ReturnPolicy')
    #
    # Core deliberately ships this one rule and no policy engine
    # (decisions.md 2026-08-03): the hook is the extension point, and a
    # richer rules model can arrive behind it without changing its contract.
    class EligibilityValidator
      # @param workflow [Spree::Returns::Create, Spree::Exchanges::Create]
      def call(workflow)
        order = workflow.order
        window = window_for(order)

        return if window.nil?
        return if order.completed_at.nil?
        return if order.completed_at > window.days.ago
        # Staff opened this, so treat the window as advisory — a supervisor
        # making an exception is ordinary retail, and Shopify behaves the
        # same way. The override is attributable through `created_by`.
        return if workflow.created_by.present?

        workflow.reject!(
          Spree.t('return_errors.outside_window', days: window)
        )
      end

      private

      # Market first, because the window is a per-region legal matter. An
      # order without a market (single-region store, or one placed before
      # markets existed) falls back to the preference default.
      def window_for(order)
        market = order.market
        return market.preferred_return_window_days if market.present?

        Spree::Market.new.preferred_return_window_days
      end
    end
  end
end
