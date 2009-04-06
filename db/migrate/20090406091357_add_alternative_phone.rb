class AddAlternativePhone < ActiveRecord::Migration
  def self.up
    add_column :addresses, :alternative_phone, :string
  end

  def self.down
    remove_column :addresses, :alternative_phone
  end
end
