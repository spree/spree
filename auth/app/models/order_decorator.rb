Order.class_eval do
  def token
    user.token if user.guest?
  end
end