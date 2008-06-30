class CreateOptions < ActiveRecord::Migration
  def self.up
    create_table :options do |t|
      t.column :product_id, :integer
      t.column :title, :string
    end
  end

  def self.down
    drop_table :options
  end
end
