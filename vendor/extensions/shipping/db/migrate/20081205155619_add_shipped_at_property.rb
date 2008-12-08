class AddShippedAtProperty < ActiveRecord::Migration
  def self.up
    change_table :shipments do |t|
      t.string :number
      t.decimal :cost, :precision => 8, :scale => 2
      t.datetime :shipped_at
    end
  end

  def self.down
    change_table :shipments do |t|
      t.remove :number
      t.remove :cost
      t.remove :shipped_at
    end
  end
end