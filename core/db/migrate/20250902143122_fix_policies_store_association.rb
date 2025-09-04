class FixPoliciesStoreAssociation < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_policies, :owner, polymorphic: true, index: true

    Spree::Policy.reset_column_information
    Spree::Policy.all.each do |policy|
      policy.update(owner: policy.store)
    end

    remove_index :spree_policies, [:store_id, :slug], unique: true
    remove_index :spree_policies, [:store_id, :position]
    remove_column :spree_policies, :store_id

    add_index :spree_policies, [:owner_id, :owner_type, :slug], unique: true
    add_index :spree_policies, [:owner_id, :owner_type, :position]
  end
end
