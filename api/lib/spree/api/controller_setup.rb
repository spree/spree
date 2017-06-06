require 'spree/api/responders'

module Spree
  module Api
    module ControllerSetup
      def self.included(klass)
        klass.class_eval do
          include CanCan::ControllerAdditions
          include Spree::Core::ControllerHelpers::Auth

          self.responder = Spree::Api::Responders::AppResponder
          respond_to :json
        end
      end
    end
  end
end
