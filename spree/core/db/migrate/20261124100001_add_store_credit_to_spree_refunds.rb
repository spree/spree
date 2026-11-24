# A refund paid as store credit names the credit it was paid with, so the
# refund row can record the money given back while the credit holds it.
class AddStoreCreditToSpreeRefunds < ActiveRecord::Migration[8.1]
  def change
    add_reference :spree_refunds, :store_credit, index: true
  end
end
