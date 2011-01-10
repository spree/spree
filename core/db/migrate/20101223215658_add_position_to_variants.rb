class AddPositionToVariants < ActiveRecord::Migration
  def self.up
    add_column :variants, :position, :integer
  end

  def self.down
    remove_column :variants, :position
  end
end
