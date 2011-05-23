class Admin::PromotionRulesController < Admin::BaseController
  def create
    @promotion = Promotion.find(params[:promotion_id])
    @promotion_rule = params[:promotion_rule][:type].constantize.new(params[:promotion_rule])
    @promotion_rule.promotion = @promotion
    if @promotion_rule.save
      flash[:notice] = I18n.t(:successfully_created, :resource => I18n.t(:promotion_rule))
    end
    respond_to do |format|
      format.html { redirect_to edit_admin_promotion_path(@promotion)}
      format.js   { render :layout => false }
    end
  end
  
  def destroy
    @promotion = Promotion.find(params[:promotion_id])
    @promotion_rule = @promotion.promotion_rules.find(params[:id])
    if @promotion_rule.destroy
      flash[:notice] = I18n.t(:successfully_removed, :resource => I18n.t(:promotion_rule))
    end
    respond_to do |format|
      format.html { redirect_to edit_admin_promotion_path(@promotion)}
      format.js   { render :layout => false }
    end  
  end
end
