class Admin::AdjustmentsController < Admin::BaseController

  before_filter :load_order, :only => [:index, :new, :create, :edit, :update]
  before_filter :load_adjustment, :only => [:edit, :update]

  resource_controller
  belongs_to :order
  destroy.success.wants.js { @order.reload && render_js_for_destroy }

  def index
    render
  end

  def new
    @adjustment = @order.adjustments.build
  end

  def edit
    render
  end

  def update
    if @adjustment.update_attributes(params[:adjustment])
      redirect_to admin_order_adjustments_path(@order), :notice => "Successfully updated!"
    else
      render :action => :edit
    end
  end

  def create
    @adjustment = @order.adjustments.create(params[:adjustment])
    if @adjustment.errors.any?
      render :action => :new
    else
      redirect_to admin_order_adjustments_path(@order), :notice => "Successfully created!"
    end
  end

  private

  def load_order
    @order = Order.find_by_number(params[:order_id])
  end

  def load_adjustment
    @adjustment = @order.adjustments.find(params[:id])
  end

end
