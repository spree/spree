class Promotion < ActiveRecord::Base
  has_many  :promotion_credits,    :as => :adjustment_source
  has_calculator
  alias credits promotion_credits
  
  has_many :promotion_rules
  accepts_nested_attributes_for :promotion_rules
  alias_method :rules, :promotion_rules

  MATCH_POLICIES = %w(all any)

  scope :automatic, where("code IS NULL OR code = ''")


  def eligible?(order)
    !expired? && rules_are_eligible?(order)
  end
  
  def expired?
    starts_at && Time.now < starts_at ||
    expires_at && Time.now > expires_at || 
    usage_limit && promotion_credits.with_order.count >= usage_limit
  end

  def rules_are_eligible?(order)
    return true if rules.none?
    if match_policy == 'all'
      rules.all?{|r| r.eligible?(order)}
    else
      rules.any?{|r| r.eligible?(order)}
    end
  end

  def create_discount(order)
    return if order.promotion_credits.reload.detect { |credit| credit.adjustment_source_id == self.id }
    if eligible?(order) and amount = calculator.compute(order.line_items)
      amount = order.item_total if amount > order.item_total
      order.promotion_credits.reload.clear unless combine? and order.promotion_credits.all? { |credit| credit.adjustment_source.combine? }
      order.save
      promotion_credits.create({
          :order_id => order.id, 
          :description => "#{I18n.t(:coupon)} (#{code})"
        })
    end
  end
  


  # Products assigned to all product rules
  def products
    @products ||= rules.of_type("Promotion::Rules::Product").map(&:products).flatten.uniq
  end

end
