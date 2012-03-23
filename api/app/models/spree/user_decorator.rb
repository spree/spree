Spree::User.class_eval do
  def generate_api_key!
    self.api_key = SecureRandom.hex(24)
    save!
  end

  def clear_api_key!
    self.api_key = nil
    save!
  end
end
