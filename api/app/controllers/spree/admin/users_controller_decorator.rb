Spree::Admin::UsersController.class_eval do
  before_filter :load_roles, :only => [:edit, :new, :update, :create, :generate_api_key, :clear_api_key]

  def generate_api_key
    if @user.generate_api_key!
      flash.notice = t('key_generated', :scope => 'spree.api')
    end
    redirect_to edit_admin_user_path(@user)
  end

  def clear_api_key
    if @user.clear_api_key!
      flash.notice = t('key_cleared', :scope => 'spree.api')
    end
    redirect_to edit_admin_user_path(@user)
  end
end
