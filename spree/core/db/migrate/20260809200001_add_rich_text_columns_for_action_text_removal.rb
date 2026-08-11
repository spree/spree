class AddRichTextColumnsForActionTextRemoval < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_collections, :description, :text, if_not_exists: true
    add_column :spree_collection_translations, :description, :text, if_not_exists: true

    add_column :spree_policies, :body, :text, if_not_exists: true
    add_column :spree_policy_translations, :body, :text, if_not_exists: true

    add_column :spree_customers, :internal_note, :text, if_not_exists: true
  end
end
