class CreateStones < ActiveRecord::Migration
  def self.up
    create_table :stones do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :stones
  end
end
