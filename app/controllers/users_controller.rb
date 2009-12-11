class UsersController < Spree::BaseController
  resource_controller
  
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]

  ssl_required :new, :create, :edit, :update, :show
  
  actions :all, :except => [:index, :destroy]
	
	#Cannot use resource_controller for create action
	#as openID expects block passed to user.save method
	def create
	  @user = User.new(params[:user])
	  @user.save do |result|
	    if result
	      flash[:notice] = t(:user_created_successfully) unless session[:return_to]
	      @user.roles << Role.find_by_name("admin") unless admin_created?
	      respond_to do |format|
	        format.html { redirect_back_or_default products_url }
	        format.js { render :js => true.to_json }
	      end
	    else
	      respond_to do |format|
	        format.html { render :action => :new }
	        format.js { render :js => @user.errors.to_json }
	      end
	    end
	  end
	end

  show.before :show_before
  new_action.before :new_action_before

  def update
    @user = current_user
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
    
    def show_before
      @orders = @user.orders.checkout_complete 
    end
    
    def new_action_before
      flash.now[:notice] = I18n.t(:please_create_user) unless admin_created?
    end

end
