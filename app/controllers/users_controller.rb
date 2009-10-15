class UsersController < Spree::BaseController
  resource_controller
  
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]
  before_filter :initialize_extension_partials

  ssl_required :new, :create, :edit, :update, :show
  
  actions :all, :except => [:index, :destroy]

  def create
    @user = User.new(params[:user])
    @user.save do |result|
      if result
        flash[:notice] = t(:user_created_successfully)
        @user.roles << Role.find_by_name("admin") unless admin_created?
        redirect_back_or_default account_url
      else
        render :action => :new
      end
    end
  end

  show.before do
    @orders = @user.orders.checkout_complete 
  end
  
  new_action.before { flash.now[:notice] = I18n.t(:please_create_user) unless admin_created? }

  def update
    @user = @current_user  
    @user.openid_identifier = nil
    if @user.update_attributes(params[:user])
      flash[:notice] = t("account_updated")
      redirect_to account_url
    else
      render :action => :edit
    end
  end

  private

    def object
      @user = @current_user
      @user ||= User.new(params[:user]) if params[:user]
      @user ||= User.new
      @user
    end

end
