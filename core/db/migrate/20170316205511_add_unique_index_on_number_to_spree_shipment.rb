class AddUniqueIndexOnNumberToSpreeShipment < ActiveRecord::Migration[5.0]
  def change
    unless index_exists?(:spree_shipments, :number, unique: true)
      numbers = Spree::Shipment.group(:number).having('sum(1) > 1').pluck(:number)
      shipments = Spree::Shipment.where(number: numbers)

      shipments.find_each do |shipment|
        shipment.number = shipment.class.number_generator.method(:generate_permalink).call(shipment.class)
        shipment.save
      end

      remove_index :spree_shipments, :number if index_exists?(:spree_shipments, :number)
      add_index :spree_shipments, :number, unique: true
    end
  end
end
