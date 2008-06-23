class CreatePropertiesPrototypes < ActiveRecord::Migration
  def self.up
    create_table :properties_prototypes, :id => false do |t|
      t.integer :prototype_id
      t.integer :property_id
    end
  end

  def self.down
    drop_table :properties_prototypes
  end
end
