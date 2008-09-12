class CreateTaxons < ActiveRecord::Migration
  def self.up
    create_table :taxons do |t|
      t.integer :taxonomy_id, :null => false, :references => :taxonomies
      t.integer :parent_id, :references => :taxons
      t.integer :position, :default => 0
      t.string :name, :null => false
      t.string :presentation, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :taxons
  end
end
