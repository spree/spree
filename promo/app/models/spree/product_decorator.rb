Spree::Product.class_eval do
  has_and_belongs_to_many :promotion_rules, :join_table => :spree_products_promotion_rules

  def possible_promotions
    promotion_ids = promotion_rules.map(&:activator_id).uniq
    Spree::Promotion.advertised.where(:id => promotion_ids).reject(&:expired?)
  end
end
