class AddUniqueIndexOnNumberToSpreeOrders < ActiveRecord::Migration[5.0]
  def change
    unless index_exists?(:spree_orders, :number, unique: true)
      numbers = Spree::Order.group(:number).having('sum(1) > 1').pluck(:number)
      orders = Spree::Order.where(number: numbers)

      orders.find_each do |order|
        order.number = order.class.number_generator.method(:generate_permalink).call(order.class)
        order.save
      end

      remove_index :spree_orders, :number if index_exists?(:spree_orders, :number)
      add_index :spree_orders, :number, unique: true
    end
  end
end
