Admin::UsersController.class_eval do

  def generate_api_key
    if object.generate_api_key!
      self.notice = t('api.key_generated')
    end
    redirect_to edit_object_path
  end

  def clear_api_key
    if object.clear_api_key!
      self.notice = t('api.key_cleared')
    end
    redirect_to edit_object_path
  end

end