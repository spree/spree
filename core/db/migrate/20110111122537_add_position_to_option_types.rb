class AddPositionToOptionTypes < ActiveRecord::Migration
  def self.up
    add_column :option_types, :position, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :option_types, :position
  end
end
