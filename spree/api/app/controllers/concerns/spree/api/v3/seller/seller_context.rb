module Spree
  module Api
    module V3
      module Seller
        # Resolves which seller a request acts as.
        #
        # The inverse of the admin branch's store context: there, the store is
        # named by a header or a key and falls back to the default. Here the
        # seller is named by the header, membership is checked against it, and
        # the store is *derived* from the seller — never sent, never defaulted.
        # A request that names no seller the caller belongs to has no tenant at
        # all, which is an error rather than a default.
        #
        # Included into both branch anchors (BaseController and
        # ResourceController) — parallel chains, so a concern on one is not on
        # the other.
        module SellerContext
          extend ActiveSupport::Concern

          SELLER_HEADER = 'X-Spree-Seller-Id'.freeze

          # Prepended, like the admin branch's store context, because the
          # shared base chain reads the store while setting up locale and
          # currency — before any ordinary callback runs.
          #
          # Resolving a seller needs the caller, so this identifies them first
          # by calling `authenticate_user`, which is idempotent and is the same
          # method the authentication callback runs later. That later callback
          # remains the authority on whether the request may proceed; this only
          # establishes the tenant early enough for the chain beneath it.
          included do
            prepend_before_action :set_current_seller_context
          end

          # The seller this request acts as, or nil when the header names none
          # the caller belongs to.
          #
          # @return [Spree::Seller, nil]
          # `||=` rather than a `defined?` memo on purpose: a nil must not
          # stick. The locale/currency chain reads `current_store` — and so
          # this — before authentication has run, and caching that first miss
          # would leave a controller which skips the context callback
          # (MeController) permanently seller-less even with a valid header.
          def current_seller
            @current_seller ||= resolve_current_seller
          end

          # Derived from the seller, so a seller can never widen their reach by
          # sending a store header.
          #
          # Falls back to the default store only when no seller resolved — such
          # a request is already being rejected, and the chain beneath this
          # (locale and currency setup) reads the store before the rejection
          # renders. Nothing tenant-bearing is served through the fallback.
          #
          # @return [Spree::Store, nil]
          def current_store
            current_seller&.store || Spree::Store.default
          end

          private

          def set_current_seller_context
            # Identify the caller before resolving their seller. Safe to call
            # here: it only populates @current_user, and the authentication
            # callback still decides whether an unidentified request proceeds.
            authenticate_user

            # Assigned even when nil: leaving the previous request's value on a
            # reused thread would expose another tenant to anything reading it
            # before the rejection lands.
            Spree::Current.store = current_store

            # An unauthenticated request has no seller to resolve, and saying
            # so is authentication's job — let it answer with a 401 rather than
            # reporting a missing tenant.
            return true if current_user.nil?

            require_current_seller!
          end

          def require_current_seller!
            return true if current_seller

            render_error(
              code: ErrorHandler::ERROR_CODES[:access_denied],
              message: Spree.t(:seller_access_denied),
              status: :forbidden
            )
            false
          end

          # Membership is holding a role the seller owns — the same question
          # the store back office asks, pointed at a different resource. A
          # header naming a seller the caller has no role on resolves to
          # nothing, so it reads as "no such seller" rather than "denied",
          # which is also what stops the header being used to enumerate.
          def resolve_current_seller
            return nil if seller_id_header.blank?
            return nil unless current_user.respond_to?(:sellers)

            id = Spree::Seller.decode_own_prefixed_id(seller_id_header)
            return nil if id.blank?

            current_user.sellers.find_by(id: id)
          end

          def seller_id_header
            request.headers[SELLER_HEADER]
          end
        end
      end
    end
  end
end
