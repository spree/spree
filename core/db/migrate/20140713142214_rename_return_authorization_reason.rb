class RenameReturnAuthorizationReason < ActiveRecord::Migration
  def change
    rename_column :spree_return_authorizations, :reason, :memo
  end
end
