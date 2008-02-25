class CreateSkus < ActiveRecord::Migration
  def self.up
    create_table :skus do |t|
      t.column :number, :string
      t.column :stockable_id, :integer
      t.column :stockable_type, :string
    end
  end

  def self.down
    drop_table :skus
  end
end
