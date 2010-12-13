class Admin::ShipmentsController < Admin::BaseController
  before_filter :load_data, :except => [:country_changed, :index]

  resource_controller
  belongs_to :order

  update.wants.html do
    if @order.completed?
      redirect_to edit_object_url
    else
      redirect_to admin_order_adjustments_url(@order)
    end
  end

  create do
    wants.html { redirect_to edit_object_url }
  end

  edit.before :edit_before

  update.before :assign_inventory_units
  update.after :update_after

  create.before :assign_inventory_units

  destroy.success.wants.js { render_js_for_destroy }

  def fire
    if @shipment.send("#{params[:e]}")
      flash.notice = t('shipment_updated')
    else
      flash[:error] = t('cannot_perform_operation')
    end
    redirect_to :back
  end

  private
  def build_object
    @object ||= end_of_association_chain.send parent? ? :build : :new
    @object.address ||= @order.ship_address
    @object.address ||= Address.new(:country_id => Spree::Config[:default_country_id])
    @object.shipping_method ||= @order.shipping_method
    @object.attributes = object_params
    @object
  end

  def load_data
    load_object
    @selected_country_id ||= @order.bill_address.country_id unless @order.nil? || @order.bill_address.nil?
    @selected_country_id ||= Spree::Config[:default_country_id]
    @shipping_methods = ShippingMethod.all_available(@order, :back_end)

    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')
    @countries = Country.all
  end

  def edit_before # copy into instance variable before editing
    @shipment.special_instructions = @order.special_instructions
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

end
