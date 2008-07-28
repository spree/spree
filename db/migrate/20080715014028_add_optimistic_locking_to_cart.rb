class AddOptimisticLockingToCart < ActiveRecord::Migration
  def self.up
    change_table :carts do |t|
      t.integer :lock_version, :default => 0
    end
  end

  def self.down
    change_table :carts do |t|
      t.remove :lock_version
    end
  end
end
