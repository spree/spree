require 'spree/api/responders'

module Spree
  module Api
    module ControllerSetup
      def self.included(klass)
        klass.class_eval do
          include AbstractController::Rendering
          include AbstractController::ViewPaths
          include AbstractController::Callbacks
          include AbstractController::Helpers

          include ActiveSupport::Rescuable

          include ActionController::Rendering
          include ActionController::ImplicitRender
          include ActionController::Rescue
          include ActionController::MimeResponds
          include ActionController::Head

          include CanCan::ControllerAdditions
          include Spree::Core::ControllerHelpers::Auth

          self.responder = Spree::Api::Responders::AppResponder
          respond_to :json
        end
      end
    end
  end
end
