class NamespaceTokenizedPermission < ActiveRecord::Migration
  def change
    rename_table :tokenized_permissions, :spree_tokenized_permissions
  end
end
