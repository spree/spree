Order.class_eval do
  token_resource

  # Associates the specified user with the order and destroys any previous association with guest user if
  # necessary.
  def associate_user!(user)
    self.user = user
    self.email = user.email
    # disable validations since this can cause issues when associating an incomplete address during the address step
    save(:validate => false)
  end

  # TODO: validate the format of the email as well (but we can't rely on authlogic anymore to help with validation)
  validates_presence_of :email, :if => :require_email
  validates_format_of :email, :with => /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i, :if => :require_email
end
