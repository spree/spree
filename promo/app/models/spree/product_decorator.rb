Spree::Product.class_eval do
  has_and_belongs_to_many :promotion_rules, :join_table => 'spree_products_promotion_rules'

  def possible_promotions
    all_rules = promotion_rules
    promotion_ids = all_rules.map(&:activator_id).uniq
    Spree::Promotion.advertised.where(:id => promotion_ids)
  end
end
