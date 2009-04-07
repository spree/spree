class AddProductDimensions < ActiveRecord::Migration
  def self.up
    change_table :variants do |t|
      t.decimal :weight, :precision => 8, :scale => 2
      t.decimal :height, :precision => 8, :scale => 2
      t.decimal :width, :precision => 8, :scale => 2
      t.decimal :depth, :precision => 8, :scale => 2
    end
  end

  def self.down
    change_table :variants do |t|
      t.remove :weight
      t.remove :height
      t.remove :width
      t.remove :depth
    end
  end
end