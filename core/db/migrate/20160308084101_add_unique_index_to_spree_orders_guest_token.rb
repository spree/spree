class AddUniqueIndexToSpreeOrdersGuestToken < ActiveRecord::Migration
  def up
    # there should be no more than several duplicated tokens even for largest stores
    Spree::Order.group(:guest_token).having('count(*) > 1').pluck(:guest_token).each do |token|
      Spree::Order.where(guest_token: token).each do |order|
        order.guest_token = nil
        order.send(:create_token)
      end
    end
    remove_index :spree_orders, :guest_token
    add_index :spree_orders, :guest_token, unique: true
  end

  def down
    remove_index :spree_orders, :guest_token
    add_index :spree_orders, :guest_token
  end
end

