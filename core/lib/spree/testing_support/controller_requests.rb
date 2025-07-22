module Spree
  module TestingSupport
    module ControllerRequests
      extend ActiveSupport::Concern

      included do
        routes { Spree::Core::Engine.routes }
      end
    end
  end
end
