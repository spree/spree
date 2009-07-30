class RenameChargesToAdjustments < ActiveRecord::Migration
  def self.up
    rename_table :charges, :adjustments
    add_column   :adjustments, :secondary_type, :string

    execute 'UPDATE adjustments SET secondary_type = type;'
    execute "UPDATE adjustments SET type='Charge' WHERE type LIKE '%Charge';"

    rename_column :orders, :charge_total, :adjustment_total
    rename_column :adjustments, :charge_source_id, :adjustment_base_id
    rename_column :adjustments, :charge_source_type, :adjustment_base_type
  end

  def self.down
    rename_column :adjustments, :adjustment_base_id, :charge_source_id 
    rename_column :adjustments, :adjustment_base_type, :charge_source_type

    rename_column :orders, :adjustment_total, :charge_total
    execute 'UPDATE adjustments SET type = secondary_type;'

    rename_table :adjustments, :charges
    remove_column :adjustments, :secondary_type
  end
end
