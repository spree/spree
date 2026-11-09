# Set when the merchant asks the buyer to pay a draft order; until then the
# draft stays out of the buyer's reach (see Spree::Orders::RequestPayment).
class AddPaymentRequestedAtToSpreeOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_orders, :payment_requested_at, :datetime
  end
end
