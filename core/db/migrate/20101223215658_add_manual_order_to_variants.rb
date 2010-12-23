class AddManualOrderToVariants < ActiveRecord::Migration
  def self.up
    add_column :variants, :manual_order, :integer
  end

  def self.down
    remove_column :variants, :manual_order
  end
end
