class CreateGateways < ActiveRecord::Migration
  def self.up
    create_table :gateways do |t|
      t.string :clazz
      t.string :name
      t.text :description
      t.boolean :active
      t.timestamps
    end
  end

  def self.down
    drop_table :gateways
  end
end
