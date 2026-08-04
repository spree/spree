class RenameUserIdToCustomerId < ActiveRecord::Migration[7.2]
  def change
    # Drop the lone DB-level FK constraint (Spree convention: no foreign key constraints).
    reversible do |dir|
      dir.up do
        if foreign_key_exists?(:spree_payment_sources, :spree_users, column: :user_id)
          remove_foreign_key :spree_payment_sources, :spree_users, column: :user_id
        end
      end
    end

    rename_column :spree_orders, :user_id, :customer_id
    rename_column :spree_addresses, :user_id, :customer_id
    rename_column :spree_credit_cards, :user_id, :customer_id
    rename_column :spree_store_credits, :user_id, :customer_id
    rename_column :spree_wishlists, :user_id, :customer_id
    rename_column :spree_gift_cards, :user_id, :customer_id
    rename_column :spree_gateway_customers, :user_id, :customer_id
    rename_column :spree_payment_sources, :user_id, :customer_id
    rename_column :spree_newsletter_subscribers, :user_id, :customer_id
    rename_column :spree_promotion_rule_users, :user_id, :customer_id

    # Polymorphic membership — rename both id and type so
    # `belongs_to :customer, polymorphic: true` resolves.
    rename_column :spree_customer_group_users, :user_id, :customer_id
    rename_column :spree_customer_group_users, :user_type, :customer_type
  end
end
