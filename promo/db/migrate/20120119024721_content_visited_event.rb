# LandingPage used to support static pages, we've moved to a static
# event. This adds path to promotions then migrates the old LandingPage rules
class ContentVisitedEvent < ActiveRecord::Migration

  # Removed Class for Migrations
  class Spree::Promotion::Rules::LandingPage < Spree::PromotionRule
    preference :path, :string
    def eligible?(order, options = {})
      true
    end
  end

  def up
    add_column :spree_activators, :path, :string

    Spree::Promotion::Rules::LandingPage.all.each do |promotion_rule|
      promotion = promotion_rule.promotion
      say "migrating #{promotion.name} promotion to use 'spree.content.visited' event"
      promotion.event_name = 'spree.content.visited'
      promotion.path = promotion_rule.preferred_path
      promotion.promotion_rules.delete promotion_rule
      promotion.save(:validate => false)
    end
  end

  def down
    remove_column :spree_activators, :path
  end
end