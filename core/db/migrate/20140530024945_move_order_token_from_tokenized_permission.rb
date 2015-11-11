class MoveOrderTokenFromTokenizedPermission < ActiveRecord::Migration
  def up
    execute(<<-'SQL'.squish)
      UPDATE spree_orders
        SET guest_token = spree_tokenized_permissions.token
        FROM spree_tokenized_permissions
        WHERE spree_tokenized_permissions.permissable_id = spree_orders.id
        AND spree_tokenized_permissions.permissable_type = 'Spree::Order'
    SQL
  end

  def down
  end
end
