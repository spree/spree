class AddLabelToSpreeAddresses < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_addresses, :label, :string unless column_exists?(:spree_addresses, :label)
  end
end
