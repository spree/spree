CheckoutController.class_eval do
  before_filter :apply_pending_promotions

  def apply_pending_promotions
    # apply all promotions that may have been triggered before theorder had been created
    if current_user
      current_user.pending_promotions.each do |promotional|
        promotional.promotion.activate(:order => @order, :user => current_user)
        promotional.destroy
      end
    end
  end
end
