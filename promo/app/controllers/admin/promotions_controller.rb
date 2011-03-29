class Admin::PromotionsController < Admin::ResourceController
  before_filter :load_data

  protected

  def build_resource
    @promotion = Promotion.new(params[:promotion])
    if params[:promotion] && params[:promotion][:calculator_type]
      @promotion.calculator = params[:promotion][:calculator_type].constantize.new
    end
    @promotion
  end

  def location_after_save
    edit_admin_promotion_url(@promotion)
  end

  def load_data
    @calculators = Promotion::Actions::CreateAdjustment.calculators
  end
end
