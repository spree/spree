module Spree
  class Activator < ActiveRecord::Base

    def self.active
      where('starts_at IS NULL OR starts_at < ?', Time.now).
        where('expires_at IS NULL OR expires_at > ?', Time.now)
    end

    def activate(payload)
    end

    def expired?
      starts_at && Time.now < starts_at || expires_at && Time.now > expires_at
    end
  end
end
