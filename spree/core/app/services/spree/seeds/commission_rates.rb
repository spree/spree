module Spree
  module Seeds
    # The marketplace's own commission rate, at the bottom of the list.
    #
    # Only one rate is seeded, and deliberately so. The list is the precedence
    # — resolution walks it top-down and stops at the first match — so what a
    # marketplace needs out of the box is a floor that catches everything,
    # with room above it for the narrower rates an operator adds later.
    #
    # That gives the order merchants asked for without hardcoding a ladder:
    # a new product-, category- or seller-targeted rate is created at the top
    # of the list (see Spree::CommissionRate), so it lands above this one and
    # ahead of anything more general already there. Reordering afterwards is
    # dragging a row.
    #
    # Seeding empty placeholder rates for each dimension would be worse than
    # nothing: a rate with no rules charges every sale, so three of them would
    # each shadow everything below.
    #
    # Disabled on arrival — a marketplace that has not set its terms should
    # charge nothing rather than a number core invented. Enabling it and
    # setting the value is the operator's first commission decision.
    class CommissionRates
      prepend Spree::ServiceModule::Base

      DEFAULT_CODE = 'marketplace-default'.freeze

      def call
        Spree::Store.find_each do |store|
          # Live rows only, matching the partial unique index: an operator who
          # deleted the seeded fallback gets it back on the next run rather
          # than being left with no bottom-of-list catch-all forever.
          next if store.commission_rates.exists?(code: DEFAULT_CODE)

          rate = store.commission_rates.create!(
            name: Spree.t('seed.commission_rates.marketplace_default'),
            code: DEFAULT_CODE,
            kind: 'percentage',
            value: 0,
            enabled: false
          )

          # New rates are born at the top, which is right for one an operator
          # adds and wrong for this one: it matches every sale, so anywhere but
          # the bottom leaves the rates below it unreachable. A store seeded
          # after it already has rates would otherwise have them all shadowed
          # the moment this was enabled.
          rate.move_to_bottom
        end
      end
    end
  end
end
