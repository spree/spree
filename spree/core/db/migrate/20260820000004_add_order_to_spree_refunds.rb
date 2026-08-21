class AddOrderToSpreeRefunds < ActiveRecord::Migration[8.1]
  def change
    # Which order this refund is against.
    #
    # A refund used to reach its order through its payment, which works while
    # one payment belongs to one order. In a split checkout the payment belongs
    # to the group and covers several orders, so the refund has to say which
    # one it is putting right — the seller's books, the commission reversal and
    # the payment share all have to agree on the answer.
    #
    # Nullable, and backfilled from the payment for existing rows: every refund
    # written before this column belongs to a payment that belongs to exactly
    # one order, so the answer is already in the data.
    add_reference :spree_refunds, :order, index: true

    reversible do |direction|
      direction.up do
        # A correlated UPDATE rather than Active Record: the same statement
        # runs on every adapter, and a migration should not depend on models
        # that may be renamed long after it has run.
        execute <<~SQL.squish
          UPDATE spree_refunds
          SET order_id = (
            SELECT order_id FROM spree_payments
            WHERE spree_payments.id = spree_refunds.payment_id
          )
          WHERE order_id IS NULL
        SQL
      end
    end
  end
end
