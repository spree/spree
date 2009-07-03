class AddIsoCountryInformation < ActiveRecord::Migration
  def self.up
    change_table :countries do |t|
      t.column :iso, :string, :size => 2
      t.column :printable_name, :string, :size => 80
      t.column :iso3, :string, :size => 3
      t.column :numcode, :integer      
    end
  end

  def self.down
    change_table :countries do |t|
      t.remove :iso
      t.remove :printable_name
      t.remove :iso3
      t.remove :numcode
    end
  end
end
