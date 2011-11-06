class MatchPolicyForPromotions < ActiveRecord::Migration
  def change
    add_column :promotions, :match_policy, :string, :default => 'all'
  end
end
