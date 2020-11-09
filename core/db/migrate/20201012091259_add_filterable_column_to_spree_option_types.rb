class AddFilterableColumnToSpreeOptionTypes < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_option_types, :filterable, :boolean, default: true, null: false
    add_index :spree_option_types, :filterable
  end
end
