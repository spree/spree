class Admin::UsersController < Admin::BaseController
  resource_controller
  before_filter :load_user_roles, :only => [:edit, :new, :update, :create]
  
  create.after do   
    save_user_roles
  end

  update.before do
    save_user_roles
  end
                
  private
  def load_user_roles
    load_object
    @all_roles = Role.find(:all)
    @all_roles.each { |role|
      role['user_is'] = @user.has_role?(role.name) ? true : false
    }
  end
  
  def save_user_roles
    return unless params[:user]
    @user.roles.delete_all
    Role.find(:all).each { |role|
      @user.roles << role if !params[:user]['role_' + role.name].blank?
    }
  end
end