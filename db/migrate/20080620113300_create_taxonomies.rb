class CreateTaxonomies < ActiveRecord::Migration
  def self.up
    create_table :taxonomies do |t|
      t.string :name, :null => false
      t.string :presentation, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :taxonomies
  end
end
