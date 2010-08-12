class AddAdjustmentsIndex < ActiveRecord::Migration
  def self.up
    add_index(:adjustments, :order_id)
  end

  def self.down
    remove_index(:adjustments, :order_id)
  end
end

