Admin::UsersController.class_eval do
  
  before_filter :load_roles, :only => [:edit, :new, :update, :create, :generate_api_key, :clear_api_key]

  def generate_api_key
    if object.generate_api_key!
      flash.notice = t('api.key_generated')
    end
    redirect_to edit_object_path
  end

  def clear_api_key
    if object.clear_api_key!
      flash.notice = t('api.key_cleared')
    end
    redirect_to edit_object_path
  end

end