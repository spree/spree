Spree::OrderUpdater.class_eval do
  unless self.method_defined?('update_adjustments_with_promotion_limiting')
    def update_adjustments_with_promotion_limiting
      update_adjustments_without_promotion_limiting
      return if adjustments.promotion.eligible.none?
      most_valuable_adjustment = adjustments.promotion.eligible.max{|a,b| a.amount.abs <=> b.amount.abs}
      current_adjustments = (adjustments.promotion.eligible - [most_valuable_adjustment])
      current_adjustments.each do |adjustment|
        adjustment.update_attribute_without_callbacks(:eligible, false)
      end
    end
    alias_method_chain :update_adjustments, :promotion_limiting
  end
end
