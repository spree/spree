class GenerateAnonymousUsers < ActiveRecord::Migration
  def up
    Spree::LegacyUser.table_name = 'users'
    Spree::Order.table_name = 'orders'

    Spree::LegacyUser.reset_column_information
    Spree::Order.where(:user_id => nil).each do |order|
      user = Spree::User.anonymous!
      user.email ||= order.email
      order.user = user
      order.save!
    end

    Spree::LegacyUser.table_name = 'spree_users'
    Spree::Order.table_name = 'spree_orders'
  end

  def down
  end
end
