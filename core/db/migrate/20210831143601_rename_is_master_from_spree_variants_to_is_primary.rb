class RenameIsMasterFromSpreeVariantsToIsPrimary < ActiveRecord::Migration[6.1]
  def change
    rename_column :spree_variants, :is_master, :is_primary
  end
end
