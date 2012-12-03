class Spree::Admin::PromotionRulesController < Spree::Admin::BaseController
  helper 'spree/promotion_rules'

  def create
    @promotion = Spree::Promotion.find(params[:promotion_id])
    # Remove type key from this hash so that we don't attempt
    # to set it when creating a new record, as this is raises
    # an error in ActiveRecord 3.2.
    promotion_rule_type = params[:promotion_rule].delete(:type)
    @promotion_rule = promotion_rule_type.constantize.new(params[:promotion_rule])
    @promotion_rule.promotion = @promotion
    if @promotion_rule.save
      flash[:success] = I18n.t(:successfully_created, :resource => I18n.t(:promotion_rule))
    end
    respond_to do |format|
      format.html { redirect_to spree.edit_admin_promotion_path(@promotion)}
      format.js   { render :layout => false }
    end
  end

  def destroy
    @promotion = Spree::Promotion.find(params[:promotion_id])
    @promotion_rule = @promotion.promotion_rules.find(params[:id])
    if @promotion_rule.destroy
      flash[:success] = I18n.t(:successfully_removed, :resource => I18n.t(:promotion_rule))
    end
    respond_to do |format|
      format.html { redirect_to spree.edit_admin_promotion_path(@promotion)}
      format.js   { render :layout => false }
    end
  end
end
