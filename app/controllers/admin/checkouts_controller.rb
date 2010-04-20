class Admin::CheckoutsController  < Admin::BaseController
  resource_controller :singleton
  actions :edit, :update, :show
  belongs_to :order
  before_filter :load_data
  ssl_required

  edit.before :edit_before
  update.before :update_before

  update.wants.html do
    if @order.in_progress?
      redirect_to edit_admin_order_shipment_url(@order, @order.shipment)
    else
      redirect_to admin_order_checkout_url(@order)
    end
  end

  private
  def load_data
    @countries = Country.find(:all).sort
    if params[:checkout] && params[:checkout][:bill_address_attributes]
      default_country = Country.find params[:checkout][:bill_address_attributes][:country_id]
    elsif params[:checkout] && params[:checkout][:ship_address_attributes]
      default_country = Country.find params[:checkout][:ship_address_attributes][:country_id]
    elsif object.bill_address && object.bill_address.country
      default_country = object.bill_address.country
    elsif current_user && current_user.bill_address
      default_country = current_user.bill_address.country
    else
      default_country = Country.find Spree::Config[:default_country_id]
    end
    @states = default_country.states.sort
  end

  def edit_before
    @checkout.build_bill_address(:country_id => Spree::Config[:default_country_id]) if @checkout.bill_address.nil?
    @checkout.build_ship_address(:country_id => Spree::Config[:default_country_id]) if @checkout.ship_address.nil?
  end

  def update_before
    @checkout.enable_validation_group(:address)

    #assign order to existing user
    @checkout.order.update_attribute(:user_id, params[:user_id]) unless params[:user_id].blank?
  end
end
