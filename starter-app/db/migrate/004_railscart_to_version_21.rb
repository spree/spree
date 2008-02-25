class RailscartToVersion21 < ActiveRecord::Migration
  def self.up
    Engines.plugins["railscart"].migrate(21)
  end

  def self.down
    Engines.plugins["railscart"].migrate(0)
  end
end
