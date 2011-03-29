class EligibleForAdjustments < ActiveRecord::Migration
  def self.up
    add_column :adjustments, :eligible, :boolean, :default => true
  end

  def self.down
    remove_column :adjustments, :eligible
  end
end
