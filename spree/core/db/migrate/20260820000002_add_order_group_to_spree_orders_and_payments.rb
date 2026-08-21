class AddOrderGroupToSpreeOrdersAndPayments < ActiveRecord::Migration[8.1]
  def change
    # Which seller sold this order, and which checkout it was placed in. Both
    # nullable: a store selling only its own goods never sets either, and the
    # first-party child of a mixed checkout carries a group but no seller.
    add_reference :spree_orders, :seller, index: true
    add_reference :spree_orders, :order_group, index: true

    # A grouped checkout's payment belongs to the group rather than to any one
    # child order — there is one charge, and the per-order shares are
    # spree_payment_splits rows. An ungrouped order keeps payments.order_id.
    add_reference :spree_payments, :order_group, index: true
  end
end
