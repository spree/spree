class Admin::UsersController < Admin::BaseController
  resource_controller                                                             
  before_filter :initialize_extension_partials
  before_filter :load_roles, :only => [:edit, :new, :update, :create]
  
  create.after do   
    save_user_roles
  end

  update.before do
    save_user_roles
  end
                
  private
  def collection   
    @search = User.new_search(params[:search])
    #set order by to default or form result
    @search.order_by ||= :email
    @search.order_as ||= "ASC"
    #set results per page to default or form result
    @search.per_page = Spree::Config[:admin_products_per_page]

    @collection, @collection_count = @search.all, @search.count

    #scope = scope.conditions "lower(email) = ?", @filter.email.downcase unless @filter.email.blank?
  end

  def load_roles
    @roles = Role.all
  end
  
  def save_user_roles
    return unless params[:user]
    @user.roles.delete_all
    params[:user][:role] ||= {}
    params[:user][:role][:user] = 1     # all new accounts have user role 
    Role.all.each { |role|
      @user.roles << role unless params[:user][:role][role.name].blank?
    }
    params[:user].delete(:role)
  end
end
