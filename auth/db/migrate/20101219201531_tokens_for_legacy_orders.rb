class TokensForLegacyOrders < ActiveRecord::Migration
  def up
    # add token permissions for legacy orders (stop relying on user persistence token)
    Spree::Order.all.each do |order|
      next unless order.user
      order.create_tokenized_permission(:token => order.user.persistence_token)
    end
  end

  def down
  end
end
