class AddAdjustmentsIndex < ActiveRecord::Migration
  def change
    add_index :adjustments, :order_id
  end
end

