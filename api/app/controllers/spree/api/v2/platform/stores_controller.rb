module Spree
  module Api
    module V2
      module Platform
        class StoresController < ::Spree::Api::V2::Platform::ResourceController
          private

          def model_class
            Spree::Store
          end

          def resource
            @resource ||= scope.find_by!(code: params[:code])
          end
        end
      end
    end
  end
end
