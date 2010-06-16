class Admin::ShipmentsController < Admin::BaseController
  before_filter :load_data, :except => :country_changed
  before_filter :require_object_editable_by_current_user, :only => [:update]

  resource_controller
  belongs_to :order

  update.wants.html do
    if @order.in_progress?
      redirect_to admin_order_adjustments_url(@order)
    else
      redirect_to edit_object_url
    end
  end

  create do
    wants.html { redirect_to edit_object_url }
  end

  edit.before :edit_before

  update.before :assign_inventory_units
  update.after :update_after

  create.before :assign_inventory_units
  create.after :recalculate_order

  destroy.success.wants.js { render_js_for_destroy }

  def fire
    @shipment.send("#{params[:e]}!")
    flash.notice = t('shipment_updated')
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
    @selected_country_id = params[:shipment_presenter][:address_country_id].to_i if params.has_key?('shipment_presenter')
    @selected_country_id ||= @order.bill_address.country_id unless @order.nil? || @order.bill_address.nil?
    @selected_country_id ||= Spree::Config[:default_country_id]
    @shipping_methods = ShippingMethod.all_available(@order, :back_end)

    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')
    @countries = Checkout.countries.sort
    @countries = [Country.find(Spree::Config[:default_country_id])] if @countries.empty?
  end

  def edit_before # copy into instance variable before editing
    @shipment.special_instructions = @order.checkout.special_instructions
  end

  def update_after # copy back to order if instructions are enabled
    @order.checkout.special_instructions = object_params[:special_instructions] if Spree::Config[:shipping_instructions]
    @order.checkout.shipping_method = @order.shipment.shipping_method
    @order.save
    recalculate_order
  end

  def assign_inventory_units
    return unless params.has_key? :inventory_units
    #params[:inventory_units].each { |id, value| @shipment.inventory_units << InventoryUnit.find(id) }
    @shipment.inventory_unit_ids = params[:inventory_units].keys
  end

  def recalculate_order
    @shipment.recalculate_order if params[:recalculate]
  end

end
