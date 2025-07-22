module Spree
  module Core
    module ControllerHelpers
      module Turbo
        extend ActiveSupport::Concern

        included do
          if defined?(helper_method)
            helper_method :turbo_frame_request?, :turbo_stream_request?
          end
        end

        def turbo_stream_request?
          request.format.turbo_stream?
        end
      end
    end
  end
end
