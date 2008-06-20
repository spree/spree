class CreateGatewayOptionValues < ActiveRecord::Migration
  def self.up
    create_table :gateway_option_values do |t|
      t.references :gateway_configuration
      t.references :gateway_option
      t.text :value
      t.timestamps
    end
  end

  def self.down
    drop_table :gateway_option_values
  end
end
