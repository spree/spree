class ScopeSpreeRoleNameUniquenessToAudience < ActiveRecord::Migration[8.1]
  # Staff and vendor roles are independent vocabularies, so a marketplace
  # naturally wants "Manager" on both sides. The old index made the name
  # globally unique across every audience, which turned that ordinary case
  # into a validation failure.
  def change
    remove_index :spree_roles, :name, unique: true
    add_index :spree_roles, [:name, :audience], unique: true
  end
end
