require 'mail'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'sprockets/railtie'
require 'spree/core'

module Spree
  module Emails
  end
end

require 'spree/emails/engine'
