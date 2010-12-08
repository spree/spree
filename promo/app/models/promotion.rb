class Promotion < ActiveRecord::Base
  has_many  :promotion_credits,    :as => :source
  calculated_adjustments
  alias credits promotion_credits

  has_many :promotion_rules
  accepts_nested_attributes_for :promotion_rules
  alias_method :rules, :promotion_rules

  validates :name, :code, :presence => true

  MATCH_POLICIES = %w(all any)

  scope :automatic, where("code IS NULL OR code = ''")

  def eligible?(order)
    !expired? && rules_are_eligible?(order)
  end

  def expired?
    starts_at && Time.now < starts_at ||
    expires_at && Time.now > expires_at ||
    usage_limit && credits_count >= usage_limit
  end

  def credits_count
    credits.with_order.count
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
    return if order.promotion_credit_exists?(self)
    if eligible?(order) and amount = calculator.compute(order)
      amount = order.item_total if amount > order.item_total
      order.promotion_credits.reload.clear unless combine? and order.promotion_credits.all? { |credit| credit.source.combine? }
      order.promotion_credits.create({
          :label => "#{I18n.t(:coupon)} (#{code})",
          :source => self,
          :amount => -amount.abs
        })
      order.update!
    end
  end



  # Products assigned to all product rules
  def products
    @products ||= rules.of_type("Promotion::Rules::Product").map(&:products).flatten.uniq
  end

end
