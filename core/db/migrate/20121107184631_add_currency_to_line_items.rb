class AddCurrencyToLineItems < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :currency, :string
  end
end
