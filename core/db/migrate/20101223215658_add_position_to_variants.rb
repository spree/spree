class AddPositionToVariants < ActiveRecord::Migration
  def change
    add_column :variants, :position, :integer
  end
end
