class SpreeToVersion21 < ActiveRecord::Migration
  def self.up
    Engines.plugins["spree"].migrate(21)
  end

  def self.down
    Engines.plugins["spree"].migrate(0)
  end
end
