class AddressesController < Spree::BaseController
  resource_controller
  belongs_to :user
  before_filter :load_data, :only => [:new, :edit]

  index.response do |wants|
    wants.html
    wants.js do
      if current_user 
        render :json => { :addresses => current_user.addresses }.to_json
      else
        render :json => { :addresses => '' }.to_json
      end
    end
  end

  create.before do
    @object.nickname = @object.address1 if @object.nickname.blank?
    @object.user_id = @user.id
  end

  destroy.before do
    @ship_orders = Order.find_by_ship_address_id(@object.id)
    @bill_orders = Order.find_by_bill_address_id(@object.id)
    if @ship_orders || @bill_orders
      @object.active = 0
      @object.save
      #DON'T DESTROY ADDRESS
    end
  end

  update.before do
    @ship_orders = Order.find_by_ship_address_id(@object.id)
    @bill_orders = Order.find_by_bill_address_id(@object.id)
    if @ship_orders || @bill_orders
      @object.active = 0
      @object.save
      #CREATE NEW ADDRESS INSTEAD OF EDIT
    end
    @object.nickname = @object.address1 if @object.nickname.blank?
  end

  create.response do |wants|
    wants.html { redirect_to user_addresses_url(@user.id) }
  end

  update.response do |wants|
    wants.html { redirect_to user_addresses_url(@user.id) }
  end
  destroy.response do |wants|
    wants.html { redirect_to user_addresses_url(@user.id) }
  end

  def load_data
    @countries = Country.find(:all).sort
    @states = Country.find(214).states.sort
  end
end
