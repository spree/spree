User.class_eval do

  def clear_api_key!
    self.update_attribute(:authentication_token, "")
  end

  def generate_api_key!
    self.update_attribute(:authentication_token, secure_digest(Time.now, (1..10).map{ rand.to_s }))
  end

  private

  def secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end

end