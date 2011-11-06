class EligibleForAdjustments < ActiveRecord::Migration
  def change
    add_column :adjustments, :eligible, :boolean, :default => true
  end
end
