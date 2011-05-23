# A rule to limit a promotion based on products in the order.
# Can require all or any of the products to be present.
# Valid products either come from assigned product group or are assingned directly to the rule.
class Promotion::Rules::Product < PromotionRule

  belongs_to :product_group
  has_and_belongs_to_many :products, :class_name => '::Product', :join_table => 'products_promotion_rules', :foreign_key => 'promotion_rule_id'

  MATCH_POLICIES = %w(any all)
  preference :match_policy, :string, :default => MATCH_POLICIES.first

  # scope/association that is used to test eligibility
  def eligible_products
    product_group ? product_group.products : products
  end

  def eligible?(order, options = {})
    return true if eligible_products.empty?
    if preferred_match_policy == 'all'
      eligible_products.all? {|p| order.products.include?(p) }
    else
      order.products.any? {|p| eligible_products.include?(p) }
    end
  end


  def products_source=(source)
    if source.to_s == 'manual'
      self.product_group_id = nil
    end
  end

  def product_ids_string
    product_ids.join(',')
  end
  def product_ids_string=(s)
    self.product_ids = s.to_s.split(',').map(&:strip)
  end

end
