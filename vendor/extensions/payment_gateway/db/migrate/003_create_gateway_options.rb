class CreateGatewayOptions < ActiveRecord::Migration
  def self.up
    create_table :gateway_options do |t|
      t.string :name
      t.text :description
      t.references :gateway
      t.boolean :textarea, :default => false
      t.timestamps
    end
  end

  def self.down
    drop_table :gateway_options
  end
end
