class UsersController < Spree::BaseController
  create.before do
    @user.login = @user.email 
  end
end