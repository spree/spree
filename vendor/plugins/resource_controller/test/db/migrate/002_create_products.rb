class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :products
  end
end
