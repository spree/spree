class TokensForLegacyOrders < ActiveRecord::Migration
  def up
    Spree::TokenizedPermission.table_name = 'tokenized_permissions'

    # add token permissions for legacy orders (stop relying on user persistence token)
    Spree::Order.all.each do |order|
      next unless order.user
      permission = order.build_tokenized_permission
      permission.token = order.user.persistence_token
      permission.save!
    end

    Spree::TokenizedPermission.table_name = 'spree_tokenized_permissions'
  end

  def down
  end
end
