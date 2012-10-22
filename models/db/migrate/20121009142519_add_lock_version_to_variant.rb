class AddLockVersionToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :lock_version, :integer, :default => 0
  end
end
