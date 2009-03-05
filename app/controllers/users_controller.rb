class UsersController < Spree::BaseController
  
#  before_filter :login_required, :except => [:new, :create]
  before_filter :initialize_extension_partials
  
  resource_controller
  actions :all, :except => [:index, :destroy]
  
  show.before do
    @orders = Order.checkout_completed(true).find_all_by_user_id(current_user.id)
  end
                 
  create do
    flash nil
    wants.html { redirect_back_or_default(products_path) }         
  end
  
  create.after do
    @user.roles << Role.find_by_name("user")
    @user.save   
    self.current_user = @user       
  end
  
end
