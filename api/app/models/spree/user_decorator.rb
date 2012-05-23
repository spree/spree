if Spree.user_class
  Spree.user_class.class_eval do
    def generate_api_key!
      self.api_key = SecureRandom.hex(24)
      save!
    end

    def clear_api_key!
      self.api_key = nil
      save!
    end
  end
end
