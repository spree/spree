class Spree::Admin::PromotionActionsController < Spree::Admin::BaseController
  def create
    @calculators = Spree::Promotion::Actions::CreateAdjustment.calculators
    @promotion = Spree::Promotion.find(params[:promotion_id])
    @promotion_action = params[:action_type].constantize.new(params[:promotion_action])
    @promotion_action.promotion = @promotion
    if @promotion_action.save
      flash[:success] = I18n.t(:successfully_created, :resource => I18n.t(:promotion_action))
    end
    respond_to do |format|
      format.html { redirect_to spree.edit_admin_promotion_path(@promotion)}
      format.js   { render :layout => false }
    end
  end

  def destroy
    @promotion = Spree::Promotion.find(params[:promotion_id])
    @promotion_action = @promotion.promotion_actions.find(params[:id])
    if @promotion_action.destroy
      flash[:success] = I18n.t(:successfully_removed, :resource => I18n.t(:promotion_action))
    end
    respond_to do |format|
      format.html { redirect_to spree.edit_admin_promotion_path(@promotion)}
      format.js   { render :layout => false }
    end
  end
end
