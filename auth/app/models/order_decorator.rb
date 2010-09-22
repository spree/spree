Order.class_eval do
  # Associates the specified user with the order and destroys any previous association with guest user if
  # necessary.
  def associate_user!(user)
    update_attributes_without_callbacks({
      :user_id => user,
      :email => user.email
    })
  end

  def token
    user.token if user.anonymous?
  end

  validates_format_of :email, :with => Authlogic::Regex.email, :if => :require_email

end
