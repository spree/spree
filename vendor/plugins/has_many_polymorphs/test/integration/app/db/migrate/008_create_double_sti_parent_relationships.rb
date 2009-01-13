class CreateDoubleStiParentRelationships < ActiveRecord::Migration
  def self.up
    create_table :double_sti_parent_relationships do |t|
      t.column :the_bone_type, :string, :null => false
      t.column :the_bone_id, :integer, :null => false
      t.column :parent_type, :string, :null => false
      t.column :parent_id, :integer, :null => false
    end
  end

  def self.down
    drop_table :double_sti_parent_relationships
  end
end
