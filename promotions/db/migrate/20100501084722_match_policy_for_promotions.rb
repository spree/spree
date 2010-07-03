class MatchPolicyForPromotions < ActiveRecord::Migration
  def self.up
    add_column "promotions", "match_policy", :string, :default => 'all'
  end

  def self.down
    remove_column "promotions", "match_policy"
  end
end