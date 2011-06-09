FEATURES_PATH = File.expand_path('../..', __FILE__)

# load shared env with features
require File.expand_path('../../../../features/support/env', __FILE__)

Spree::Auth::Config.set(:registration_step => true)
Spree::Auth::Config.set(:signout_after_password_change => false)
