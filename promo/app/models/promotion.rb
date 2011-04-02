class Promotion < ActiveRecord::Base
  has_many  :promotion_credits,    :as => :source
  calculated_adjustments
  alias credits promotion_credits

  has_many :promotion_rules, :autosave => true
  accepts_nested_attributes_for :promotion_rules
  alias_method :rules, :promotion_rules

  validates :name, :presence => true

  # TODO: Remove that after fix for https://rails.lighthouseapp.com/projects/8994/tickets/4329-has_many-through-association-does-not-link-models-on-association-save
  # is provided
  def save(*)
    if super
      promotion_rules.each { |p| p.save }
    end
  end

  MATCH_POLICIES = %w(all any)

  scope :automatic, where("code IS NULL OR code = ''")
  scope :manual, where("code IS NOT NULL AND code <> ''")

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
      order.update!
      PromotionCredit.create!({
          :label => "#{I18n.t(:coupon)} (#{code})",
          :source => self,
          :amount => -amount.abs,
          :order => order
        })
    end
  end



  # Products assigned to all product rules
  def products
    @products ||= rules.of_type("Promotion::Rules::Product").map(&:products).flatten.uniq
  end

end
