class CreateOptionTypesPrototypes < ActiveRecord::Migration
  def self.up
    create_table :option_types_prototypes, :id => false do |t|
      t.integer :prototype_id
      t.integer :option_type_id
    end
  end

  def self.down
    drop_table :option_types_prototypes
  end
end
