class UsersController < Spree::BaseController
  resource_controller
  
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]
  before_filter :initialize_extension_partials

  actions :all, :except => [:index, :destroy]
  
  def create
    @user = User.new(params[:user])
    @user.roles << Role.find_by_name("user")
    if @user.save
      redirect_back_or_default products_path
    else
      render :action => :new
    end
  end

  show.before do
    @orders = Order.checkout_completed(true).find_all_by_user_id(current_user.id)
  end

  def update
    @user = @current_user
    if @user.update_attributes(params[:user])
      flash[:notice] = t("account_updated")
      redirect_to account_url
    else
      render :action => :edit
    end
  end


  private
    def object
      @object ||= current_user
    end

end
