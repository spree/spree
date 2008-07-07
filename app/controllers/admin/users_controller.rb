class Admin::UsersController < Spree::BaseController
  resource_controller
  
  create.before do
    @user.login = @user.email 
  end  
end