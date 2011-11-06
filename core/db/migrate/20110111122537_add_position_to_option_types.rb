class AddPositionToOptionTypes < ActiveRecord::Migration
  def change
    add_column :option_types, :position, :integer, :null => false, :default => 0
  end
end
