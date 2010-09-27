Order.class_eval do
  delegate :token, :to => :user

  # Associates the specified user with the order and destroys any previous association with guest user if
  # necessary.
  def associate_user!(user)
    self.user = user
    self.email = user.email
    # disable validations since this can cause issues when associating an incomplete address during the address step
    save(:validate => false)
  end

  validates_format_of :email, :with => Authlogic::Regex.email, :if => :require_email

end
