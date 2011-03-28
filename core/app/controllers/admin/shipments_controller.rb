class Admin::ShipmentsController < Admin::BaseController
  before_filter :load_order
  before_filter :load_shipment, :only => [:destroy, :edit, :update]
  before_filter :load_shipping_methods, :except => [:country_changed, :index]

  def index
    @shipments = @order.shipments
    respond_to { |format| format.html }
  end

  def new
    build_shipment
    @shipment.address ||= @order.ship_address
    @shipment.address ||= Address.new(:country_id => Spree::Config[:default_country_id])
    @shipment.shipping_method = @order.shipping_method
    respond_to { |format| format.html }
  end

  def create
    build_shipment
    assign_inventory_units
    respond_to do |format|
      format.html do
        if @shipment.save
          flash[:notice] = I18n.t(:successfully_created, :resource => 'shipment')
          redirect_to edit_admin_order_shipment_path(@order, @shipment)
        else
          render :action => 'new'
        end
      end
    end
  end


  def edit
    @shipment.special_instructions = @order.special_instructions
    respond_to do |format|
      format.html { render :action => 'edit' }
    end
  end

  def update
    assign_inventory_units
    respond_to do |format|
      format.html do
        if @shipment.update_attributes params[:shipment]
          update_after
          flash[:notice] = I18n.t(:successfully_updated, :resource => I18n.t('shipment'))
          if @order.completed?
            redirect_to edit_admin_order_shipment_path(@order, @shipment)
          else
            redirect_to admin_order_adjustments_url(@order)
          end
        else
          render :action => 'edit'
        end
      end
    end
  end

  def destroy
    @shipment.destroy
    respond_to do |format|
      format.js { render_js_for_destroy }
    end
  end

  def fire
    if @shipment.send("#{params[:e]}")
      flash.notice = t('shipment_updated')
    else
      flash[:error] = t('cannot_perform_operation')
    end
    redirect_to :back
  end

  private

  def load_shipping_methods
    @shipping_methods = ShippingMethod.all_available(@order, :back_end)
  end

  def update_after # copy back to order if instructions are enabled
    @order.special_instructions = object_params[:special_instructions] if Spree::Config[:shipping_instructions]
    @order.shipping_method = @order.shipment.shipping_method
    @order.save
  end

  def assign_inventory_units
    return unless params.has_key? :inventory_units
    @shipment.inventory_unit_ids = params[:inventory_units].keys
  end

  def load_order
    @order = Order.find_by_number(params[:order_id])
  end

  def load_shipment
    @shipment = Shipment.find_by_number(params[:id])
  end

  def build_shipment
    @shipment = @order.shipments.build
    @shipment.address ||= @order.ship_address
    @shipment.address ||= Address.new(:country_id => Spree::Config[:default_country_id])
    @shipment.shipping_method ||= @order.shipping_method
    @shipment.attributes = params[:shipment]
  end

end
