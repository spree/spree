class AddPriceSourceToSpreeLineItems < ActiveRecord::Migration[8.1]
  def change
    # Which engine priced this line. NULL means Spree's own catalog, where
    # price_list_id already says which list won; a value names the provider,
    # because an external price leaves no catalog row to point at and an order
    # still has to be able to say why it charged what it charged.
    add_column :spree_line_items, :price_source, :string
  end
end
