class Admin::ShipmentsController < Admin::BaseController
  before_filter :load_data, :except => :country_changed
  before_filter :load_shipment_presenter, :only => [:create, :update]

  resource_controller
  belongs_to :order
  
  # override r_c default with special presenter logic
  def create  
    # TODO - provide AJAX interface for setting shipping method instead of assuming first available
    shipment = @shipment_presenter.shipment
    shipment.order = @order
    shipment.shipping_method = ShippingMethod.first
    shipment.address = @shipment_presenter.address
    unless @shipment_presenter.valid? and shipment.save
      render :action => "new" and return
    end 
    @order.state_events.create(:name => t('ship'), :user => current_user, :previous_state => @order.state) if params[:mark_shipped]  
    flash[:notice] = t('created_successfully')
    redirect_to collection_url
  end

  # override r_c default with special presenter logic
  def edit 
    @shipment_presenter = ShipmentPresenter.new(:shipment => object, :address => object.address)    
  end

  # override r_c default with special presenter logic
  def update
    @shipment.address = @shipment_presenter.address 
    @shipment.tracking = @shipment_presenter.shipment.tracking
    @shipment.cost = @shipment_presenter.shipment.cost
    @shipment.shipped_at = Time.now if params[:mark_shipped]    
    unless @shipment_presenter.valid? and @shipment.save
      render :action => "edit" and return
    end
    @order.state_events.create(:name => t('ship'), :user => current_user, :previous_state => @order.state) if params[:mark_shipped]
    flash[:notice] = t('updated_successfully')
    redirect_to edit_object_url
  end

  def country_changed
    @selected_country_id = params[:shipment_presenter][:address_country_id].to_i if params.has_key?('shipment_presenter')
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
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
  
  def load_shipment_presenter
    @shipment_presenter = ShipmentPresenter.new(params[:shipment_presenter])     
  end

end