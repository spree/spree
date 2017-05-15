module Spree
  module UserApiAuthentication
    def generate_spree_api_key!
      self.spree_api_key = generate_spree_api_key
      save!
    end

    def clear_spree_api_key!
      self.spree_api_key = nil
      save!
    end

    private

    def generate_spree_api_key
      token = SecureRandom.urlsafe_base64
      while self.class.exists?(spree_api_key: token)
        token = SecureRandom.urlsafe_base64
      end
      token
    end
  end
end
