class AccountController < Spree::BaseController
  before_filter :login_from_cookie

  def index
    redirect_to(login_path) unless logged_in? || User.count > 0
  end

  def login
    return unless request.post?
    self.current_user = User.authenticate(params[:email], params[:password])
    if logged_in?
      if params[:remember_me] == "1"
        self.current_user.remember_me
        cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
      end
      redirect_back_or_default(products_path)
      flash.now[:notice] = t("logged_in_successfully")
    else
      flash.now[:error] = t("login_authentication_failed")
    end
  end 
  
  def logout
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = t("you_have_been_logged_out")
    redirect_back_or_default('/')
    #redirect_back_or_default(:controller => '/account', :action => 'index')
  end
end
