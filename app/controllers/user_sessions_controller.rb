class UserSessionsController < Spree::BaseController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  ssl_required :new, :create, :destroy, :update
  ssl_allowed :login_bar
    
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    success = @user_session.save 
    respond_to do |format|
      format.html {                                
        if success 
          flash[:notice] = t("logged_in_succesfully")
          redirect_back_or_default products_path
        else
          flash.now[:error] = t("login_failed")
          render :new
        end
      }
      format.js {
        render :js => success.to_json
      }
    end    
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = t("logged_out")
    redirect_to products_path
  end
  
  def login_bar
    render :partial => "shared/login_bar"
  end
end
