Order.class_eval do
  # Associates the specified user with the order and destroys any previous association with guest user if
  # necessary.
  def associate_user!(user)
    self.user = user
    self.email = user.email
    save!
  end

  def token
    user.token if user.anonymous?
  end

  validates_presence_of :email, :on => :update
  validates_format_of :email, :with => Authlogic::Regex.email, :on => :update

end
