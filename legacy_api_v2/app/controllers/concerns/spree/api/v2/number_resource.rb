module Spree
  module Api
    module V2
      module NumberResource
        def resource
          @resource ||= scope.find_by(number: params[:id]) || scope.find(params[:id])
        end
      end
    end
  end
end
