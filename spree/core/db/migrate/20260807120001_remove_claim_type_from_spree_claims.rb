class RemoveClaimTypeFromSpreeClaims < ActiveRecord::Migration[8.1]
  def change
    remove_column :spree_claims, :claim_type, :string, null: false
  end
end
