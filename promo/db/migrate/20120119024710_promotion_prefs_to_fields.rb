# Up until this point Promotions stored usage_limit, match_policy, code
# and advertise in preferences. This migration creates columns for those
# values. Temporarly adds the preferences back, and migrates the data
class PromotionPrefsToFields < ActiveRecord::Migration
  def up
    drop_table :spree_pending_promotions

    add_column :spree_activators, :usage_limit, :integer
    add_column :spree_activators, :match_policy, :string, :default => 'all'
    add_column :spree_activators, :code, :string
    add_column :spree_activators, :advertise, :boolean, :default => false

    Spree::Promotion.class_eval do
      preference :usage_limit, :integer
      preference :match_policy, :string, :default => 'all'
      preference :code, :string
      preference :advertise, :boolean, :default => false
    end

    Spree::Promotion.all.each do |promotion|
      promotion.usage_limit = promotion.preferred_usage_limit
      promotion.match_policy = promotion.preferred_match_policy
      promotion.code = promotion.preferred_code
      promotion.advertise = promotion.preferred_advertise
      promotion.save
    end
  end

  def down
    remove_column :spree_activators, :usage_limit
    remove_column :spree_activators, :match_policy
    remove_column :spree_activators, :code
    remove_column :spree_activators, :advertise
  end
end