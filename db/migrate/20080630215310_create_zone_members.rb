class CreateZoneMembers < ActiveRecord::Migration
  def self.up
    create_table :zone_members do |t|
      t.references :parent
      t.references :member, :polymorphic => true
      t.timestamps
    end
  end

  def self.down
    drop_table :zone_members
  end
end
