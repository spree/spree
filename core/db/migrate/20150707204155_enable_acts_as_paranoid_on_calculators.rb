class EnableActsAsParanoidOnCalculators < ActiveRecord::Migration
  def change
    add_column :spree_calculators, :deleted_at, :datetime
    add_index :spree_calculators, :deleted_at
  end
end
