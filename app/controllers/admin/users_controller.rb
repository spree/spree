class Admin::UsersController < Admin::BaseController
  resource_controller                                                             
  before_filter :initialize_extension_partials
  before_filter :load_roles, :only => [:edit, :new, :update, :create]
  
  create.after :save_user_roles
  update.before :save_user_roles
                
  private
  def collection   
    @search = User.searchlogic(params[:search])

    #set order by to default or form result
    @search.order ||= "ascend_by_email"

    @collection_count = @search.count
    @collection = @search.paginate(:per_page => Spree::Config[:admin_products_per_page],
                                   :page     => params[:page])

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
