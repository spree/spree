class AddRefundedOrderToSpreeStoreCredits < ActiveRecord::Migration[8.1]
  def change
    add_reference :spree_store_credits, :refunded_order, index: true
  end
end
