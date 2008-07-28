class AddPermalinkAndPublishedToProducts < ActiveRecord::Migration
  def self.up
    add_column :products, :permalink, :string
    add_column :products, :available_on, :datetime

    add_index :products, :permalink
    add_index :products, :available_on
    add_index :products, [:permalink, :available_on]
  end

  def self.down
    remove_column :products, :permalink
    remove_column :products, :available_on
  end
end
