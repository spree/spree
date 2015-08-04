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
      SecureRandom.hex(24)
    end
  end
end
