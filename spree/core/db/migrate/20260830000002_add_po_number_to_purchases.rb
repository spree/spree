class AddPoNumberToPurchases < ActiveRecord::Migration[8.1]
  def change
    # The buyer's own purchase-order reference, carried from cart to order at
    # completion. A plain column on both sides rather than metadata: it is how
    # a corporate buyer's accounting finds this transaction years later, so it
    # has to be indexed and searchable.
    add_column :spree_carts, :po_number, :string
    add_column :spree_orders, :po_number, :string
    add_index :spree_orders, :po_number

    # Whether this buyer's own procurement process demands the reference.
    # Hung on the company because it describes the buyer, not the merchant's
    # agreement with them.
    add_column :spree_companies, :po_number_required, :boolean, null: false, default: false
  end
end
