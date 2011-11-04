class NamespaceTokenizedPermission < ActiveRecord::Migration
  def up
    rename_table :tokenized_permissions, :spree_tokenized_permissions
  end

  def down
    rename_table :spree_tokenized_permissions, :tokenized_permissions
  end
end
