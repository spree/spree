class RemoveHmpStuffInZones < ActiveRecord::Migration
  def self.up                          
    change_table :zone_members do |t|
      t.rename :parent_id, :zone_id  
      t.rename :member_id, :zoneable_id
      t.rename :member_type, :zoneable_type
    end
  end

  def self.down
  end
end
