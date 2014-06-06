class MoveOrderTokenFromTokenizedPermission < ActiveRecord::Migration
  class Spree::TokenizedPermission < Spree::Base
    belongs_to :permissable, polymorphic: true
  end

  def up
    case Spree::Order.connection.adapter_name
    when 'SQLite'
      Spree::Order.has_one :tokenized_permission, :as => :permissable
      Spree::Order.includes(:tokenized_permission).each do |o|
        o.update_column :token, o.tokenized_permission.token
      end
    when 'Mysql2'
      execute "UPDATE spree_orders, spree_tokenized_permissions
               SET spree_orders.token = spree_tokenized_permissions.token
               WHERE spree_tokenized_permissions.permissable_id = spree_orders.id
                  AND spree_tokenized_permissions.permissable_type = 'Spree::Order'"
    else
      execute "UPDATE spree_orders
               SET token = spree_tokenized_permissions.token
               FROM spree_tokenized_permissions
               WHERE spree_tokenized_permissions.permissable_id = spree_orders.id
                  AND spree_tokenized_permissions.permissable_type = 'Spree::Order'"
    end
  end

  def down
  end
end
