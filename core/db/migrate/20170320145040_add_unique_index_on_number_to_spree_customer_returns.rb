class AddUniqueIndexOnNumberToSpreeCustomerReturns < ActiveRecord::Migration[5.0]
  def change
    unless index_exists?(:spree_customer_returns, :number, unique: true)
      numbers = Spree::CustomerReturn.group(:number).having('sum(1) > 1').pluck(:number)
      returns = Spree::CustomerReturn.where(number: numbers)

      returns.find_each do |r|
        r.number = r.class.number_generator.method(:generate_permalink).call(r.class)
        r.save
      end

      remove_index :spree_customer_returns, :number if index_exists?(:spree_customer_returns, :number)
      add_index :spree_customer_returns, :number, unique: true
    end
  end
end
