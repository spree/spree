module Spree
  module UserApiAuthentication
    def generate_spree_api_key!
      self.spree_api_key = SecureRandom.hex(24)
      save!
    end

    def clear_spree_api_key!
      self.spree_api_key = nil
      save!
    end
  end
end
