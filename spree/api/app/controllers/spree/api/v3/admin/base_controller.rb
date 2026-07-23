module Spree
  module Api
    module V3
      module Admin
        class BaseController < Spree::Api::V3::BaseController
          include Spree::Api::V3::AdminAuthentication

          # Must be registered before ScopedAuthorization so authenticate_admin!
          # resolves @current_api_key before authorize_api_key_scope! reads it —
          # otherwise the scope guard short-circuits on a nil key and never runs.
          before_action :authenticate_admin!

          include Spree::Api::V3::ScopedAuthorization
        end
      end
    end
  end
end
