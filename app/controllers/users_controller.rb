class UsersController < Spree::BaseController
  resource_controller
  
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]
  before_filter :initialize_extension_partials
  ssl_required :new, :create, :edit, :update, :show
  
  actions :all, :except => [:index, :destroy]

  create do   
    flash nil
    wants.html { redirect_back_or_default products_path }
    wants.js { render :js => true.to_json }
    failure.wants.html { render :new }
    failure.wants.js { render :js => @user.errors.to_json }    
  end 
  
  create.after do
    next if admin_created?
    @user.roles << Role.find_by_name("admin")
  end

  show.before do
    @orders = @user.orders.checkout_complete 
  end
  
  new_action.before { flash.now[:notice] = I18n.t(:please_create_user) unless admin_created? }

  def update
    @user = @current_user
    if @user.update_attributes(params[:user])
      flash[:notice] = t("account_updated")
      redirect_to account_url
    else
      render :action => :edit
    end
  end

end
