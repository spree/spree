module Spree
  module Api
    module V3
      module Store
        class DigitalLinksController < Store::BaseController
          # Lets the Disk service build absolute URLs from the current request;
          # remote services (S3 et al.) sign without it.
          include ActiveStorage::SetCurrent

          allow_guest_storefront_access!
          skip_before_action :authenticate_api_key!
          before_action :set_resource

          # GET /api/v3/store/digital_links/:token
          #
          # Hands the customer their deliverable: a redirect to a short-lived
          # signed URL (an uploaded file, an external link) or an inline body (a
          # license key). The provider decides which; this controller only
          # settles authorization and renders the shape.
          def show
            if (delivery = authorized_delivery)
              @resource.publish_event('digital_link.downloaded')
              render_delivery(delivery)
            else
              render_error(
                code: ERROR_CODES[:digital_link_expired],
                message: 'Download link expired or invalid',
                status: :forbidden
              )
            end
          end

          private

          # Everything that can refuse is settled before the click is spent: the
          # link must permit a download, the window must be open, the provider
          # must actually produce a deliverable (a provider that errors or has
          # nothing refuses cleanly), and only then is the click consumed under
          # the lock. So a dry provider or a missing file never burns an
          # allowance.
          #
          # @return [Spree::DigitalDelivery, nil]
          def authorized_delivery
            return unless @resource.authorizable?

            window = signed_url_window
            return if window <= 0

            delivery = safe_deliver(window)
            return unless delivery&.present?
            return unless @resource.authorize!

            delivery
          end

          # A provider is external I/O; an exception must refuse, not 500, and
          # must not spend the click (it hasn't been spent yet at this point).
          def safe_deliver(window)
            @resource.digital_asset.deliver(@resource, expires_in: window)
          rescue StandardError => e
            Rails.logger.error("Digital delivery failed for #{@resource.prefixed_id}: #{e.class}: #{e.message}")
            nil
          end

          def render_delivery(delivery)
            if delivery.redirect?
              redirect_to delivery.redirect_url, allow_other_host: true
            else
              send_data delivery.inline_value,
                        type: delivery.content_type.presence || 'application/octet-stream',
                        disposition: 'inline'
            end
          end

          # The signed URL is a bearer credential, so it must never outlive the
          # link that authorized it — otherwise an expired link keeps handing
          # out working URLs for the rest of the store's window.
          def signed_url_window
            window = current_store.preferred_digital_asset_link_expire_time.seconds
            return window unless (expiry = @resource.expires_at)

            [window, expiry - Time.current].min
          end

          # The download token is the request's credential and selects the
          # store (tokens are globally unique via has_secure_token) — no
          # publishable key accompanies emailed download links, so there is no
          # other credential to derive store context from.
          def set_resource
            @resource = digital_link_scope.find_by!(token: params[:token])
            Spree::Current.store = current_store
          end

          def digital_link_scope
            Spree::DigitalLink
          end

          def current_store
            @current_store ||= @resource&.store || super
          end
        end
      end
    end
  end
end
