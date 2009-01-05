class UsersController < Spree::BaseController
  
#  before_filter :login_required, :except => [:new, :create]
  before_filter :initialize_extension_partials
  
  resource_controller
  actions :all, :except => [:index, :destroy]
  
  show.before do
    @orders = Order.checkout_completed(true).find_all_by_user_id(current_user.id)
  end

  create.after do   
    self.current_user = @user       
  end

  create.response do |wants|  
    wants.html { redirect_back_or_default(products_path) }         
  end
  
end
