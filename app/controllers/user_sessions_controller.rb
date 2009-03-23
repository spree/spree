class UserSessionsController < Spree::BaseController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
    
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Logged in successfully"
      redirect_back_or_default products_path
    else
      flash.now[:error] = "Login authentication failed."      
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "You have been logged out."
    redirect_back_or_default('/')
  end
end

=begin
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
      flash.now[:notice] = "Logged in successfully"
    else
      flash.now[:error] = "Login authentication failed."
    end
  end 
  def logout
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = "You have been logged out."
    redirect_back_or_default('/')
    #redirect_back_or_default(:controller => '/account', :action => 'index')
  end
end
=end