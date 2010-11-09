User.class_eval do

  def clear_api_key!
    self.update_attribute(:authentication_token, "")
  end

  def generate_api_key!
    self.reset_authentication_token!
  end

  #def self.authenticate_with_http(username, password)
  #  logger.debug(username)
  #  self.authenticate_with_token(:auth_token => username)
  #end

  private

  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

end