Order.class_eval do

  attr_accessible :coupon_code
  attr_accessor :coupon_code

  def promotion_credit_exists?(promotion)
    !! adjustments.promotion.reload.detect { |credit| credit.originator.promotion.id == promotion.id }
  end

  def products
    line_items.map {|li| li.variant.product}
  end

  unless self.instance_methods.include?("update_adjustments_with_promotion_limiting")
    private
    def update_adjustments_with_promotion_limiting
      return if adjustments.promotion.eligible.none?
      most_valuable_adjustment = adjustments.promotion.eligible.max{|a,b| a.amount.abs <=> b.amount.abs}
      ( adjustments.promotion.eligible - [most_valuable_adjustment] ).each{|adjustment| adjustment.update_attribute_without_callbacks(:eligible, false)}
    end
    # alias_method_chain :update_adjustments, :promotion_limiting
  end

end

Order.register_update_hook(:update_adjustments_with_promotion_limiting)