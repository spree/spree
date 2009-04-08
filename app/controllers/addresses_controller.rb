class AddressesController < Spree::BaseController
  resource_controller
  belongs_to :user
  before_filter :load_data, :only => [:new, :edit]

  create.before do
    @object.nickname = @object.address1 if @object.nickname.blank?
  end

  destroy.before do
    #TODO: If address is tied to orders, hide instead of delete
  end

  update.before do
    @object.nickname = @object.address1 if @object.nickname.blank?
    #TODO: If address is tied to orders, create instead of edit
  end

  create.response do |wants|
    wants.html { redirect_to user_addresses_url(current_user.id) }
  end

  update.response do |wants|
    wants.html { redirect_to user_addresses_url(current_user.id) }
  end
  destroy.response do |wants|
    wants.html { redirect_to user_addresses_url(current_user.id) }
  end

  def load_data
    @countries = Country.find(:all).sort
    @states = Country.find(214).states.sort
  end
end
