module Spree
  module Api
    module V3
      module Admin
        class BaseController < Spree::Api::V3::BaseController
          include Spree::Api::V3::AdminAuthentication
        end
      end
    end
  end
end
