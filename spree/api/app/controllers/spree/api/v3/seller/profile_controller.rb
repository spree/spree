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
            attributes = permitted_params.merge(terms_attributes)
            # `normalize_params` rewrites `custom_fields` to the nested-attributes
            # key. Narrow it, then hand it back under the original name: the
            # model's `custom_fields=` upserts by definition, while the nested
            # writer builds a row every time — so a seller correcting a value
            # they had already saved would hit the uniqueness index instead.
            if attributes.key?(:custom_fields_attributes)
              attributes[:custom_fields] =
                requested_custom_fields(attributes.delete(:custom_fields_attributes))
            end

            tax_identifier = attributes.delete(:tax_identifier)

            if current_seller.update(attributes)
              upsert_tax_identifier(tax_identifier) if tax_identifier.present?
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
          # Accepting the marketplace's terms is a profile write, not an endpoint
          # of its own: `accept_terms: true` stamps the time, which is what the
          # AcceptTerms requirement reads.
          #
          # Re-stamped every time rather than only on a first acceptance: a
          # marketplace that rewrites its terms advances the requirement's
          # `terms_effective_from`, which puts everyone who accepted before
          # that date back on the checklist — and a seller who could not
          # re-accept would be stuck there with nothing to click.
          #
          # One-way all the same: sending `false` is a no-op, because the
          # stamp records that acceptance happened.
          def terms_attributes
            return {} unless ActiveModel::Type::Boolean.new.cast(params[:accept_terms])

            { terms_accepted_at: Time.current }
          end

          # One registration per kind, so re-sending a kind corrects the number
          # rather than stacking a second row the model would reject.
          #
          # A changed number drops its verdict — the validator's answer was
          # about the old one, and carrying it over would show a number as
          # verified that nobody has checked.
          def upsert_tax_identifier(attributes)
            kind = attributes[:kind].presence
            return if kind.blank?

            value = attributes[:value]
            return current_seller.tax_identifiers.find_by(kind: kind)&.destroy if value.blank?

            current_seller.tax_identifiers.find_or_initialize_by(kind: kind).update(value: value)
          end

          # Narrowed to the definitions this marketplace's onboarding actually
          # asks this seller for.
          #
          # Custom fields on `Spree::Seller` are the operator's schema, and
          # some of them are the operator's own — an internal risk note, a
          # compliance flag. A seller may fill in what they were asked for;
          # permitting the association wholesale would let them write, and
          # then read back, every field the operator defined.
          def requested_custom_fields(submitted)
            return [] if submitted.blank?

            allowed = Spree::SellerRequirementCustomField.
                      joins(:seller_requirement).
                      where(Spree::SellerRequirement.table_name => {
                              store_id: current_store.id, active: true
                            }).
                      pluck(:custom_field_definition_id).to_set

            Array(submitted).select do |field|
              allowed.include?(field[:custom_field_definition_id])
            end
          end

          def permitted_params
            normalize_params(
              params.permit(:name, :contact_email, :billing_email, :about,
                            :legal_name, :registration_number,
                            :logo, :square_logo, :cover_photo,
                            tax_identifier: [:kind, :value],
                            billing_address: Spree::Api::V3::AddressParams::ADDRESS_KEYS,
                            custom_fields: [:id, :custom_field_definition_id, :value,
                                            { value: [] }, { value: {} }])
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
