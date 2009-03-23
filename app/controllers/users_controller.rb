class UsersController < Spree::BaseController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]
  #  before_filter :login_required, :except => [:new, :create]
  before_filter :initialize_extension_partials

  resource_controller
  actions :all, :except => [:index, :destroy]
  
#  def new
#    @user = User.new
#  end

  def create
    @user = User.new(params[:user])
    @user.roles << Role.find_by_name("user")
    if @user.save
      #flash nil
      #flash[:notice] = "Account registered!"
      redirect_back_or_default products_path
    else
      render :action => :new
    end
  end

  show.before do
    @orders = Order.checkout_completed(true).find_all_by_user_id(current_user.id)
  end

#  create do
#    flash nil
#    wants.html { redirect_back_or_default(products_path) }         
#  end

#  create.after do
#    @user.roles << Role.find_by_name("user")
#    @user.save   
#    #self.current_user = @user       
#  end


#  def edit
#    @user = @current_user
#  end

#  def update
#    @user = @current_user # makes our views "cleaner" and more consistent
#    if @user.update_attributes(params[:user])
#      flash[:notice] = "Account updated!"
#      redirect_to account_url
#    else
#      render :action => :edit
#    end
#  end
end
