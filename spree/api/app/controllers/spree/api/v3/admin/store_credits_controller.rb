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

          # Not `:originator`: the serializer encodes its id from the columns
          # rather than loading the record, so preloading a polymorphic
          # association would fire one query per originator kind on the page
          # and discard every row it returned.
          def collection_includes
            [:customer, :created_by]
          end

          # Pagination metadata plus the outstanding balance, one row per
          # currency, summed over the same filtered scope the page came from —
          # so a customer filter answers "this customer's balance" and no
          # filter answers "the store's liability".
          def collection_meta(_collection)
            super.merge(totals: currency_totals)
          end

          private

          # @return [Array<Hash>] one entry per currency present in the
          #   filtered scope, ordered by currency.
          def currency_totals
            base = scope
            table = Spree::StoreCredit.arel_table
            # Summed over the matching ids rather than over the joined rows: a
            # filter reaching through a `has_many` would match a credit once per
            # joined row and count its amount that many times, overstating what
            # the store owes.
            # Without the sort key: the subquery only supplies ids, so carrying
            # the page's ORDER BY (and any join it needs) buys nothing.
            filtered = base.ransack(ransack_params.except('s')).result.select(:id)
            rows = base.where(id: filtered).
                   reorder(nil).
                   order(:currency).
                   group(:currency).
                   pluck(
                     :currency,
                     table[:amount].sum,
                     table[:amount_used].sum,
                     table[:amount_authorized].sum
                   )

            rows.map do |currency, amount, used, authorized|
              # `SUM` answers an Integer on a whole-number total, and these
              # totals render beside rows that serialize decimal strings — so
              # "50" must not appear against their "50.0".
              figures = {
                amount: amount.to_d,
                amount_used: used.to_d,
                amount_authorized: authorized.to_d
              }
              figures[:amount_remaining] =
                figures[:amount] - figures[:amount_used] - figures[:amount_authorized]

              displays = figures.transform_keys { |name| :"display_#{name}" }.
                         transform_values { |value| Spree::Money.new(value, currency: currency).to_s }

              { currency: currency }.merge(figures.transform_values(&:to_s)).merge(displays)
            end
          end
        end
      end
    end
  end
end
