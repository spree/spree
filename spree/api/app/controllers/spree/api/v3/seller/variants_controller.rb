module Spree
  module Api
    module V3
      module Seller
        # A seller's offers — the rows they list against the marketplace's
        # own master-catalog products
        # (docs/plans/6.0-seller-master-catalog-listings.md).
        #
        # Rooted in `current_seller.variants`, which because of the model's
        # normalizer is exactly this seller's rows on master products: a
        # variant on a product the seller owns outright keeps its own seller
        # column blank and is edited through the products endpoint instead.
        # A rival's row on the same product is a 404, not a 403.
        #
        # This is why a seller is never handed a whole-product `variants:`
        # payload on a master: that setter is full replacement, so a narrowed
        # read plus a full write would destroy every other seller's rows
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 11).
        class VariantsController < Seller::ResourceController
          include Spree::Api::V3::Seller::CatalogParams
          include Spree::Api::V3::StatusActions

          scoped_resource :products

          before_action :set_status_resource, only: [:submit, :draft, :archive]
          before_action :validate_offer_payload, only: [:create, :update]

          # PATCH /api/v3/seller/variants/:id/submit
          #
          # Asking the marketplace to put this offer on sale.
          def submit
            run_status_workflow(Spree.variant_propose_workflow,
                                submitted_by: try_spree_current_user)
          end

          # PATCH /api/v3/seller/variants/:id/draft
          #
          # Taking an offer back down while it is worked on. Withdrawing your
          # own offer is not a review decision, so it needs nobody's approval.
          def draft
            run_status_workflow(Spree.variant_draft_workflow)
          end

          # PATCH /api/v3/seller/variants/:id/archive
          def archive
            run_status_workflow(Spree.variant_archive_workflow)
          end

          protected

          def model_class
            Spree::Variant
          end

          def serializer_class
            Spree.api.seller_variant_serializer
          end

          # `Seller#variants` — every offer this seller holds, across products.
          def seller_association
            :variants
          end

          # Set only on the nested routes, where the master product is named
          # in the path. Resolved through the same three-way narrowing the
          # catalog endpoint applies, so a seller cannot list against a
          # product that is closed, inactive, or another seller's.
          def set_parent
            return if params[:master_product_id].blank?

            @parent = current_store.products.active.for_seller(nil).open_to_sellers.
                      includes(option_types: :option_values).
                      find_by_prefix_id!(params[:master_product_id])
          end

          # Tenancy stays the seller's even with a parent: the base class
          # would read the parent's whole variants collection, which on a
          # master product is every seller's.
          def scope
            base = current_seller.variants
            base = base.where(product_id: @parent.id) if @parent.present?
            base = base.includes(scope_includes) if scope_includes.any?
            base.preload_associations_lazily
          end

          def resource_scope
            scope
          end

          def scope_includes
            [
              :prices, :submissions,
              { product: { option_types: :option_values } },
              { option_values: :option_type },
              { stock_levels: :stock_location }
            ]
          end

          def create_workflow
            Spree.variant_create_workflow
          end

          def update_workflow
            Spree.variant_update_workflow
          end

          # The workflow builds the row through the product, which would leave
          # it unowned. The seller and the opening status are set here instead,
          # so an offer is this seller's and starts as a draft whatever the
          # payload claims.
          def create_workflow_arguments
            {
              product: @parent,
              attributes: permitted_params.merge(seller_id: current_seller.id, status: 'draft')
            }
          end

          def permitted_params
            attrs = params.permit(
              :sku, :barcode,
              :cost_price, :cost_currency,
              :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
              :hs_code, :country_of_origin, :customs_description,
              :minimum_order_quantity, :order_multiple, :purchase_unit, :units_per_carton,
              :track_inventory, :preorderable, :preorder_ships_at, :backorder_limit,
              # No `seller_id`: the row carries the seller from the scope it
              # was built in. No `status`: an offer moves through the member
              # actions, so a decision always records who made it. No
              # `tax_category_id` or `position`: tax is marketplace
              # configuration, and the order of a shared product's rows is
              # the operator's.
              :delivery_profile_id,
              metadata: {},
              options: [:name, :value],
              prices: [:amount, :compare_at_amount, :currency],
              stock_levels: [:id, :stock_location_id, :count_on_hand, :backorderable]
            )

            # Assigned only when present: writing a nil `prices` or
            # `stock_levels` key reaches the association setter as nil, which
            # raises rather than meaning "leave alone".
            attrs[:prices] = default_price_currencies(attrs[:prices]) if attrs.key?(:prices)
            attrs[:stock_levels] = own_stock_levels(attrs[:stock_levels]) if attrs.key?(:stock_levels)
            attrs[:delivery_profile_id] = own_delivery_profile_id(attrs[:delivery_profile_id]) if attrs.key?(:delivery_profile_id)
            attrs[:options] = @resolved_options if @resolved_options

            attrs
          end

          private

          # An offer's option values are PICKED from what the master product
          # already carries, never created
          # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 7).
          #
          # `Variant#set_option_value` creates an option type when it does not
          # recognise the name — looked up globally, not per store — and
          # creates option values on demand, so an unfiltered payload would
          # let a seller add an axis to the operator's product, or a spelling
          # of "X-Large" to the marketplace's vocabulary that every storefront
          # filter then shows.
          #
          # Every axis must be named and every value must exist. A row missing
          # the condition axis would land in the wrong buy box, so silence is
          # never the answer — each refusal names the axis at fault.
          #
          # @return [Hash, nil] the error to render, or nil when the payload is good
          def resolve_options
            return if params[:options].blank? && action_name == 'update'

            product = @parent || @resource&.product
            return if product.nil?

            provided = Array(params[:options]).to_h { |option| [option[:name].to_s.parameterize, option] }
            resolved = []

            product.option_types.includes(:option_values).each do |option_type|
              option = provided.delete(option_type.name)

              if option.blank? || option[:value].blank?
                return option_error('missing_option_value', option_type: option_type.label)
              end

              value = option_type.option_values.detect do |candidate|
                candidate.name == option[:value].to_s.parameterize
              end
              if value.nil?
                return option_error('unknown_option_value', option_type: option_type.label, value: option[:value])
              end

              resolved << { name: option_type.name, value: value.name }
            end

            return option_error('unknown_option_type', option_type: provided.keys.first) if provided.any?

            @resolved_options = resolved
            nil
          end

          def option_error(code, **interpolations)
            {
              code: code,
              message: I18n.t("spree.api.offers.#{code}", **interpolations),
              status: :unprocessable_content
            }
          end

          # One offer per seller per option combination: a second row with the
          # same values would give a seller two competing entries in the same
          # buy box, and nothing could choose between them. Refused here rather
          # than on the model, because a first-party catalog may legitimately
          # carry duplicate combinations today
          # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 8).
          #
          # @return [Hash, nil]
          def refuse_duplicate_combination
            product = @parent || @resource&.product
            return if product.nil? || @resolved_options.nil?

            wanted = @resolved_options.map { |option| [option[:name], option[:value]] }.sort

            # Archived rows do not count: a seller who took an offer down must
            # be able to list that combination again, and the panel offers no
            # way back from `archived`.
            duplicate = current_seller.variants.where(product_id: product.id).
                        where.not(id: @resource&.id).
                        where.not(status: 'archived').
                        includes(option_values: :option_type).
                        any? { |variant| option_signature(variant) == wanted }

            return unless duplicate

            {
              code: 'duplicate_offer',
              message: I18n.t('spree.api.offers.duplicate_offer'),
              status: :unprocessable_content
            }
          end

          def option_signature(variant)
            variant.option_values.map { |value| [value.option_type.name, value.name] }.sort
          end

          # Both checks run before the workflow, so a refusal never leaves a
          # half-written row behind.
          def validate_offer_payload
            error = resolve_options || refuse_duplicate_combination
            return if error.nil?

            render_error(**error)
          end

        end
      end
    end
  end
end
