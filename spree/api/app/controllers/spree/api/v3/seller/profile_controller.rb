module Spree
  module Api
    module V3
      module Seller
        # The seller's own record, as they maintain it.
        #
        # Singular by nature: there is exactly one seller in play, and it is
        # `current_seller` — never an id from the request. A seller cannot
        # address another seller here even by guessing one.
        #
        # What they may change is presentation, contact and addresses. Absent
        # by design: `status` (the lifecycle belongs to the operator's
        # workflows), the settlement and tax configuration, and `slug` — a
        # seller renaming their own storefront address breaks every link
        # pointing at it.
        class ProfileController < Seller::BaseController
          # A singular resource, so this extends the plain base rather than
          # ResourceController — which is where the params normalizer lives.
          include Spree::Api::V3::ParamsNormalizer

          scoped_resource :seller_profile

          def show
            render json: serialize_seller
          end

          def update
            if current_seller.update(permitted_params)
              render json: serialize_seller
            else
              render_validation_error(current_seller.errors)
            end
          end

          protected

          # The params normalizer resolves nested attributes against this.
          def model_class
            Spree::Seller
          end

          def read_actions
            %w[show]
          end

          # Enumerated rather than borrowing the legacy global list, which
          # permits :id, :user_id and :deleted_at.
          ADDRESS_KEYS = [
            :first_name, :last_name, :company, :address1, :address2, :city,
            :postal_code, :zipcode, :phone, :country_code, :state_code, :state_name, :label
          ].freeze

          def permitted_params
            normalize_params(
              params.permit(:name, :contact_email, :billing_email, :about,
                            :logo, :square_logo, :cover_photo,
                            billing_address: ADDRESS_KEYS,
                            returns_address: ADDRESS_KEYS)
            )
          end

          private

          def serialize_seller
            Spree.api.seller_profile_serializer.new(
              current_seller.reload, params: { store: current_store }
            ).to_h
          end
        end
      end
    end
  end
end
