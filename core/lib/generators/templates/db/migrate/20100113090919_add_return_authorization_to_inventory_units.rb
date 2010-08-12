class AddReturnAuthorizationToInventoryUnits < ActiveRecord::Migration
  def self.up
    add_column :inventory_units, :return_authorization_id, :integer
  end

  def self.down
    remove_column :inventory_units, :return_authorization_id
  end
end
