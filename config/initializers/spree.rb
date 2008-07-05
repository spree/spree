#require 'spree'

# TODO - Add the lib/plugins stuff maybe?

ActiveRecord::Base.send :include, Spree::Preferences
Spree::Preferences::MailSettings.init
