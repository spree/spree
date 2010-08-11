class AddGuestFlag < ActiveRecord::Migration
  def self.up
    change_table :users do |t|
      t.boolean :guest
    end
  end

  def self.down
    change_table :users do |t|
      t.remove :guest
    end
  end
end
