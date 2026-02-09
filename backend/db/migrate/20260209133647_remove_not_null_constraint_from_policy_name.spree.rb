# This migration comes from spree (originally 20260117140831)
class RemoveNotNullConstraintFromPolicyName < ActiveRecord::Migration[7.2]
  def change
    change_column_null :spree_policies, :name, true
  end
end
