class Admin::ShipmentsController < Admin::BaseController
  before_filter :load_data
  resource_controller
  belongs_to :order
  
  # override r_c default with special presenter logic
  def edit 
    @shipment_presenter = ShipmentPresenter.new(:shipment => object, :address => object.address)    
  end
    
  # override r_c default with special presenter logic
  def update
    @shipment_presenter = ShipmentPresenter.new(params[:shipment_presenter])     
    @shipment.address = @shipment_presenter.address
    @shipment.tracking = @shipment_presenter.shipment.tracking
    @shipment.cost = @shipment_presenter.shipment.cost
    @shipment.shipped_at = Time.now if params[:mark_shipped]
    @shipment.save
    flash[:notice] = t("Updated Successfully")
    redirect_to edit_object_url
  end
      
  update.after do 
    if params['mark_shipped']
      @order.ship!
    end 
  end
  
  update.response do |wants|
    wants.html do 
      redirect_to admin_order_url(@order)
    end
  end
  
  def country_changed
    render :partial => "shared/states", :locals => {:presenter_type => "shipment"}
  end
  
  private
  def load_data 
    load_object
    @selected_country_id = params[:shipment_presenter][:address_country_id].to_i if params.has_key?('shipment_presenter')
    @selected_country_id ||= @order.bill_address.country_id unless @order.nil? || @order.bill_address.nil?  
    @selected_country_id ||= Spree::Config[:default_country_id]
 
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
    @countries = @order.shipping_countries
    @countries = [Country.find(Spree::Config[:default_country_id])] if @countries.empty?
  end
  
  def build_object
    @shipment_presenter ||= ShipmentPresenter.new(:address => Address.new)
  end  
  
end