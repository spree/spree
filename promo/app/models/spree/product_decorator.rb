Spree::Product.class_eval do
  has_and_belongs_to_many :promotion_rules, :join_table => 'spree_products_promotion_rules'

  def possible_promotions
    rules_with_matching_product_groups = product_groups.map(&:promotion_rules).flatten
    all_rules = promotion_rules + rules_with_matching_product_groups
    promotion_ids = all_rules.map(&:activator_id).uniq
    Spree::Promotion.advertised.where(:id => promotion_ids)
  end
end
