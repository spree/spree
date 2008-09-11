class AddressRefactor < ActiveRecord::Migration
  def self.up
    change_table :addresses do |t|
      t.references :addressable, :polymorphic => true
    end
    change_table :orders do |t|
      t.remove :ship_address_id
      t.remove :bill_address_id
    end
  end

  def self.down
  end
end
