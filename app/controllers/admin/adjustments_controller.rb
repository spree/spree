class Admin::AdjustmentsController < Admin::BaseController
  resource_controller
  belongs_to :order
  ssl_required

  before_filter :list_adjustment_types

  update.wants.html { redirect_to collection_url }
  create.wants.html { redirect_to collection_url }
  destroy.success.wants.js { render_js_for_destroy }

  create.before :set_type
  create.after :update_totals
  update.after :update_totals
  destroy.after :update_totals

  private
  def list_adjustment_types
    applicable_credits = Credit.subclasses.reject{|c| c.to_s == "CouponCredit" }
    applicable_charges = Charge.subclasses
    @adjustment_types ||= [
        [ 'Credits', applicable_credits.map {|c| [c.to_s.titleize, c.to_s]} ],
        [ 'Charges', applicable_charges.map {|c| [c.to_s.titleize, c.to_s]} ]
      ]
  end

  def set_type
    object.type = params[:adjustment][:type]
  end

  def update_totals
    @order.update_totals!
  end
end
