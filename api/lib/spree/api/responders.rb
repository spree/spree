require 'spree/api/responders/rabl_template'

module Spree
  module Api
    module Responders
      class AppResponder < ActionController::Responder
        include RablTemplate
      end
    end
  end
end
