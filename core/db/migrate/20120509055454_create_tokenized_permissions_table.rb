class CreateTokenizedPermissionsTable < ActiveRecord::Migration
  def change
    unless Spree::TokenizedPermission.table_exists?
      create_table :spree_tokenized_permissions do |t|
        t.integer :permissable_id
        t.string  :permissable_type
        t.string  :token

        t.timestamps
      end

      add_index :spree_tokenized_permissions, [:permissable_id, :permissable_type], :name => 'index_tokenized_name_and_type'
    end
  end
end

