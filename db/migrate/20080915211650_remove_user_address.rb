class RemoveUserAddress < ActiveRecord::Migration
  def self.up
    change_table :addresses do |t|
      t.remove :user_id
    end
  end

  def self.down
  end
end
