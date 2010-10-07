class DropOrderToken < ActiveRecord::Migration
  def self.up
    change_table :orders do |t|
      t.remove :token
    end
  end

  def self.down
    # no going back
  end
end
