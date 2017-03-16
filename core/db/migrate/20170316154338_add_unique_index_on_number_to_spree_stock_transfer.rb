class AddUniqueIndexOnNumberToSpreeStockTransfer < ActiveRecord::Migration[5.0]
  def change
    unless index_exists?(:spree_stock_transfers, :number, unique: true)
      numbers = Spree::StockTransfer.group(:number).having('sum(1) > 1').pluck(:number)
      transfers = Spree::StockTransfer.where(number: numbers)

      transfers.find_each do |transfer|
        transfer.number = transfer.class.number_generator.method(:generate_permalink).call(transfer.class)
        transfer.save
      end

      remove_index :spree_stock_transfers, :number if index_exists?(:spree_stock_transfers, :number)
      add_index :spree_stock_transfers, :number, unique: true
    end
  end
end
