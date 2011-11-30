module Spree
  class AuthConfiguration < Preferences::Configuration
    preference :registration_step, :boolean, :default => true
    preference :signout_after_password_change, :boolean, :default => true
  end
end
