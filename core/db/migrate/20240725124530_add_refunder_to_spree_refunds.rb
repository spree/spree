class AddRefunderToSpreeRefunds < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_refunds, :refunder_id, :bigint, if_not_exists: true
    add_index :spree_refunds, :refunder_id, if_not_exists: true
  end
end
