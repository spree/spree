class FixPoliciesStoreAssociation < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_policies, :owner, polymorphic: true, index: true

    policies = Arel::Table.new(:spree_policies)
    connection.update(
      Arel::UpdateManager.new.table(policies).set(
        [[policies[:owner_id], policies[:store_id]], [policies[:owner_type], 'Spree::Store']]
      )
    )

    remove_index :spree_policies, [:store_id, :slug], unique: true, if_exists: true
    remove_index :spree_policies, [:store_id, :position], if_exists: true
    remove_column :spree_policies, :store_id, if_exists: true
    remove_column :spree_policies, :show_in_checkout_footer, if_exists: true
    remove_column :spree_policies, :position, if_exists: true

    add_index :spree_policies, [:owner_id, :owner_type, :slug], unique: true
  end
end
