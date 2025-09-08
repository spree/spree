class FixPoliciesStoreAssociation < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_policies, :owner, polymorphic: true, index: true

    Spree::Policy.reset_column_information
    Spree::Policy.all.each do |policy|
      policy.update(owner: policy.store)
    end

    remove_index :spree_policies, [:store_id, :slug], unique: true, if_exists: true
    remove_index :spree_policies, [:store_id, :position], if_exists: true
    remove_column :spree_policies, :store_id, if_exists: true
    remove_column :spree_policies, :show_in_checkout_footer, if_exists: true
    remove_column :spree_policies, :position, if_exists: true

    add_index :spree_policies, [:owner_id, :owner_type, :slug], unique: true
  end
end
