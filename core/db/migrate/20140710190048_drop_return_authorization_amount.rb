class DropReturnAuthorizationAmount < ActiveRecord::Migration
  def change
    remove_column :spree_return_authorizations, :amount
  end
end
