module Spree
  module Api
    module V3
      module Admin
        # Cross-customer view of what the store owes in prepaid balances.
        #
        # Read-only by design: a credit always belongs to one customer, and
        # issuing, editing and deleting one stays nested under that customer
        # (`Customers::StoreCreditsController`). This list is for seeing,
        # filtering and auditing across all of them.
        class StoreCreditsController < ResourceController
          scoped_resource :store_credits

          protected

          def model_class
            Spree::StoreCredit
          end

          def serializer_class
            Spree.api.admin_store_credit_serializer
          end

          def collection_includes
            [:customer, :created_by, :originator]
          end

          # Pagination metadata plus the outstanding balance, one row per
          # currency, summed over the same filtered scope the page came from —
          # so a customer filter answers "this customer's balance" and no
          # filter answers "the store's liability".
          def collection_meta(collection)
            super.merge(totals: currency_totals)
          end

          private

          # @return [Array<Hash>] one entry per currency present in the
          #   filtered scope, ordered by currency for a stable render.
          def currency_totals
            table = Spree::StoreCredit.arel_table
            # Ransacked afresh off the bare scope: the collection carries
            # `includes(:originator)` for the rows it renders, and a polymorphic
            # association cannot be eager-loaded under an aggregate.
            # Summed over DISTINCT ids, not over the joined rows: a filter that
            # reaches through a `has_many` would otherwise match a credit once
            # per joined row and count its amount that many times, overstating
            # what the store owes. Today's allowlist only exposes `belongs_to`
            # associations, so nothing duplicates — but the liability figure
            # must not depend on that staying true.
            rows = scope.where(id: scope.ransack(ransack_params).result.select(:id)).
                   reorder(nil).
                   group(:currency).
                   pluck(
                     :currency,
                     table[:amount].sum,
                     table[:amount_used].sum,
                     table[:amount_authorized].sum
                   )

            rows.sort_by(&:first).map do |currency, amount, used, authorized|
              # `SUM` answers an Integer on a whole-number total, so cast:
              # the row serializer emits decimal strings and a totals row the
              # client renders beside them must not read "50" against "50.0".
              amount = amount.to_d
              used = used.to_d
              authorized = authorized.to_d

              {
                currency: currency,
                amount: amount.to_s,
                amount_used: used.to_s,
                amount_authorized: authorized.to_s,
                amount_remaining: (amount - used - authorized).to_s,
                display_amount: Spree::Money.new(amount, currency: currency).to_s,
                display_amount_used: Spree::Money.new(used, currency: currency).to_s,
                display_amount_authorized: Spree::Money.new(authorized, currency: currency).to_s,
                display_amount_remaining: Spree::Money.new(amount - used - authorized, currency: currency).to_s
              }
            end
          end
        end
      end
    end
  end
end
