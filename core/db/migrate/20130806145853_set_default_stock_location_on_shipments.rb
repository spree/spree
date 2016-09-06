class SetDefaultStockLocationOnShipments < ActiveRecord::Migration[4.2]
  def change
    if Spree::Shipment.where('stock_location_id IS NULL').count > 0
      location = Spree::StockLocation.find_by(name: 'default') || Spree::StockLocation.first
      Spree::Shipment.where('stock_location_id IS NULL').update_all(stock_location_id: location.id)
    end
  end
end
