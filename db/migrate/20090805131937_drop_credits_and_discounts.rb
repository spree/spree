class DropCreditsAndDiscounts < ActiveRecord::Migration
  def self.up
    drop_table :credits
    drop_table :discounts
  end

  def self.down
  end
end
