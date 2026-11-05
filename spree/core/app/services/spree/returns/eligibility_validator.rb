module Spree
  module Returns
    # The return window rule: measured from order completion, configured per
    # market.
    #
    # Registered by core on `returns.create.validate` and
    # `exchanges.create.validate`, beside ReturnableValidator and
    # DigitalContentValidator. A store that wants different rules —
    # category exclusions, per-customer-group windows, restocking fees —
    # unregisters any of them and registers its own handler:
    #
    #   Spree.hooks.unregister('returns.create.validate',
    #                          'Spree::Returns::EligibilityValidator')
    #   Spree.hooks.register('returns.create.validate', 'MyStore::ReturnPolicy')
    #
    # Core ships these rules and no policy engine (decisions.md 2026-08-03 and
    # 2026-11-03): the hook is the extension point, and a richer rules model
    # can arrive behind it without changing its contract.
    class EligibilityValidator
      # @param workflow [Spree::Returns::Create, Spree::Exchanges::Create]
      def call(workflow)
        order = workflow.order
        deadline = order.return_window_ends_at

        return if deadline.nil? || deadline.future?
        # Staff opened this, so treat the window as advisory — a supervisor
        # making an exception is ordinary retail, and Shopify behaves the
        # same way. The override is attributable through `created_by`.
        return if workflow.created_by.present?

        workflow.errors.add(
          :base,
          :outside_return_window,
          message: I18n.t('spree.return_errors.outside_window', days: order.return_window_days)
        )
        workflow.reject!
      end
    end
  end
end
