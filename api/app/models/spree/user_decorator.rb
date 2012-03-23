Spree::User.class_eval do

  def self.authenticate_for_api(key)
    !!find_by_api_key(key)
  end

  def generate_api_key!
    self.api_key = SecureRandom.hex(24)
    save!
  end

  def clear_api_key!
    self.api_key = nil
    save!
  end
end
