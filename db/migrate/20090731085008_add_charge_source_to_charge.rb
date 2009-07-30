class AddChargeSourceToCharge < ActiveRecord::Migration
  def self.up
    add_column :charges, :charge_source_id, :integer
    add_column :charges, :charge_source_type, :string
  end

  def self.down
    remove_column :charges, :charge_source_type
    remove_column :charges, :charge_source_id
  end
end
