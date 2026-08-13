module Spree
  module Api
    module V3
      module Store
        class DigitalsController < Store::BaseController
          allow_guest_storefront_access!
          skip_before_action :authenticate_api_key!
          before_action :set_resource

          # GET /api/v3/store/digitals/:token
          def show
            if @resource.authorize!
              send_data @resource.digital.attachment.download,
                        filename: @resource.digital.attachment.filename.to_s,
                        type: @resource.digital.attachment.content_type
            else
              render_error(
                code: ERROR_CODES[:digital_link_expired],
                message: 'Download link expired or invalid',
                status: :forbidden
              )
            end
          end

          private

          # The download token is the request's credential and selects the
          # store (tokens are globally unique via has_secure_token) — no
          # publishable key accompanies emailed download links, so there is
          # no other credential to derive store context from. Assigned, not
          # memoized-into: earlier prepended callbacks resolve current_store
          # before the resource exists (to the key's store, when one is
          # sent), and the link's own store must overwrite that.
          def set_resource
            @resource = digital_link_scope.find_by!(token: params[:token])
            @current_store = @resource.order.store
            Spree::Current.store = @current_store
          end

          def digital_link_scope
            Spree::DigitalLink
          end

          def current_store
            @current_store ||= super
          end
        end
      end
    end
  end
end
