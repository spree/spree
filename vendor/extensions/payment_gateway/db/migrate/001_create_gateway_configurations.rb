class CreateGatewayConfigurations < ActiveRecord::Migration
  def self.up
    create_table :gateway_configurations do |t|
      t.references :gateway
      t.timestamps
    end
  end

  def self.down
    drop_table :gateway_configurations
  end
end
