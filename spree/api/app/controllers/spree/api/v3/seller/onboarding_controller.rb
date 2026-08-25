module Spree
  module Api
    module V3
      module Seller
        # What the marketplace asks of this seller, and how far along they are.
        #
        # Singular by nature: there is exactly one seller in play and it is
        # `current_seller`, never an id from the request. The checklist is
        # computed on read through the one evaluator the operator's view and
        # the approval gate also use, so the panel and the operator can never
        # be looking at different answers.
        class OnboardingController < Seller::BaseController
          scoped_resource :seller_profile

          # GET /api/v3/seller/onboarding
          def show
            render json: onboarding_payload
          end

          # POST /api/v3/seller/onboarding/submit_for_review
          #
          # The seller says they are ready. Refused with the blocking
          # requirements named — a bare "not ready" leaves them guessing which
          # of eight things it meant.
          def submit_for_review
            result = Spree.seller_submit_for_review_workflow.call(
              seller: current_seller,
              submitted_by: try_spree_current_user
            )

            return render_service_error(result.error) unless result.success?

            render json: onboarding_payload
          end

          # POST /api/v3/seller/onboarding/payout_account
          #
          # A fresh link to wherever the provider collects what it needs before
          # it will pay this seller. Minted per request rather than rendered
          # with the checklist, because these links are short-lived and
          # single-use — one made while drawing a page is often dead by the
          # time the seller clicks it.
          #
          # The panel says where to come back to. Core does not know the
          # panel's routes, and a marketplace may host it anywhere.
          def payout_account
            provider = current_store.payout_provider_instance
            url = provider.onboarding_url(
              current_seller,
              refresh_url: params.require(:refresh_url),
              return_url: params.require(:return_url)
            )

            # No link means there is nowhere to send them — an operator paying
            # by hand collects these details themselves.
            return head :no_content if url.blank?

            render json: { url: url }
          rescue Spree::Core::GatewayError => e
            render_service_error(e.message)
          end

          protected

          def read_actions
            %w[show]
          end

          private

          def requirements
            @requirements ||= Spree::Sellers::Requirements.new(current_seller.reload)
          end

          def onboarding_payload
            {
              status: current_seller.status,
              progress: requirements.progress,
              requirements: requirements.statuses.map { |status| serialize_status(status) }
            }
          end

          def serialize_status(status)
            Spree.api.seller_requirement_status_serializer.new(
              status, params: { store: current_store }
            ).to_h
          end
        end
      end
    end
  end
end
