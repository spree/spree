module Spree
  module Api
    module V3
      module Vendor
        # Resolves which seller a request acts as.
        #
        # The inverse of the admin branch's store context: there, the store is
        # named by a header or a key and falls back to the default. Here the
        # vendor is named by the header, membership is checked against it, and
        # the store is *derived* from the vendor — never sent, never defaulted.
        # A request that names no vendor the caller belongs to has no tenant at
        # all, which is an error rather than a default.
        #
        # Included into both branch anchors (BaseController and
        # ResourceController): they are parallel inheritance chains, so a
        # concern on one is not on the other.
        module VendorContext
          extend ActiveSupport::Concern

          VENDOR_HEADER = 'X-Spree-Vendor-Id'.freeze

          # Prepended, like the admin branch's store context, because the
          # shared base chain reads the store while setting up locale and
          # currency — before any ordinary callback runs.
          #
          # Resolving a vendor needs the caller, so this identifies them first
          # by calling `authenticate_user`, which is idempotent and is the same
          # method the authentication callback runs later. That later callback
          # remains the authority on whether the request may proceed; this only
          # establishes the tenant early enough for the chain beneath it.
          included do
            prepend_before_action :set_current_vendor_context
          end

          # The vendor this request acts as, or nil when the header names none
          # the caller belongs to.
          #
          # @return [Spree::Vendor, nil]
          def current_vendor
            return @current_vendor if defined?(@current_vendor)

            @current_vendor = resolve_current_vendor
          end

          # Derived from the vendor, so a seller can never widen their reach by
          # sending a store header.
          #
          # Falls back to the default store only when no vendor resolved — such
          # a request is already being rejected, and the chain beneath this
          # (locale and currency setup) reads the store before the rejection
          # renders. Nothing tenant-bearing is served through the fallback.
          #
          # @return [Spree::Store, nil]
          def current_store
            current_vendor&.store || Spree::Store.default
          end

          private

          def set_current_vendor_context
            # Identify the caller before resolving their vendor. Safe to call
            # here: it only populates @current_user, and the authentication
            # callback still decides whether an unidentified request proceeds.
            authenticate_user

            # Assigned even when nil: leaving the previous request's value on a
            # reused thread would expose another tenant to anything reading it
            # before the rejection lands.
            Spree::Current.store = current_store

            # An unauthenticated request has no vendor to resolve, and saying
            # so is authentication's job — let it answer with a 401 rather than
            # reporting a missing tenant.
            return true if current_user.nil?

            require_current_vendor!
          end

          def require_current_vendor!
            return true if current_vendor

            render_error(
              code: ErrorHandler::ERROR_CODES[:access_denied],
              message: Spree.t(:vendor_access_denied),
              status: :forbidden
            )
            false
          end

          # Membership is holding a role the vendor owns — the same question
          # the store back office asks, pointed at a different resource. A
          # header naming a vendor the caller has no role on resolves to
          # nothing, so it reads as "no such vendor" rather than "denied",
          # which is also what stops the header being used to enumerate.
          def resolve_current_vendor
            return nil if vendor_id_header.blank?
            return nil unless current_user.respond_to?(:vendors)

            id = Spree::Vendor.decode_own_prefixed_id(vendor_id_header)
            return nil if id.blank?

            current_user.vendors.find_by(id: id)
          end

          def vendor_id_header
            request.headers[VENDOR_HEADER]
          end
        end
      end
    end
  end
end
