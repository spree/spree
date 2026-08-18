module Spree
  module Api
    module V3
      module Admin
        # What the marketplace charges its sellers, as the operator configures it.
        #
        # Targeting rides the regular payload as `rules: [...]` rather than
        # living at its own endpoint, so the whole editor saves in one
        # round-trip — the same shape price lists use.
        #
        # Operator-only: `read_commissions`/`write_commissions` is closed to the
        # seller audience, because a seller must never see, let alone set, what
        # anyone is charged.
        class CommissionRatesController < ResourceController
          scoped_resource :commissions

          # GET /api/v3/admin/commission_rates/rule_types
          #
          # Every registered rule kind with its configuration schema, so a
          # client builds its editor from what the marketplace actually has
          # rather than a list hardcoded to match core's.
          def rule_types
            authorize! :create, Spree::CommissionRule

            data = Spree.commission_rules.map do |klass|
              {
                type: klass.api_type,
                name: klass.human_name,
                description: klass.description,
                preference_schema: klass.serialized_preference_schema,
                # Config a rule takes beyond its preferences — a catalog-scale
                # reference list lives in its own table, not the blob, and an
                # editor has to know to render a picker for it.
                association_fields: association_fields_for(klass)
              }
            end

            render json: { data: data }
          end

          # A rule kind nobody registered is refused rather than skipped.
          # `assign_typed_association` drops a row it cannot resolve, which
          # would leave the rate with fewer rules than the client sent — and
          # fewer rules means a rate that charges *more* sales, so a typo would
          # silently widen what a marketplace bills.
          def create
            return if reject_unregistered_rules

            super
          end

          def update
            return if reject_unregistered_rules

            super
          end

          protected

          def model_class
            Spree::CommissionRate
          end

          def serializer_class
            Spree.api.admin_commission_rate_serializer
          end

          def scope
            super.for_store(current_store)
          end

          def collection_includes
            [:commission_rules, :commission_rate_values]
          end

          # `rule_types` is read-only discovery — maps to the read scope and
          # the :show ability rather than counting as a write.
          def read_actions
            super + %w[rule_types]
          end

          def permitted_params
            attributes = normalize_params(
              params.permit(
                :name, :code, :enabled, :position, :kind, :value,
                :tax_inclusive, :include_shipping, :commission_tax_rate,
                metadata: {},
                amounts: {},
                # Nested one level deeper than +amounts+ — currency => floor and
                # cap — so the whole subtree is permitted rather than its keys,
                # which are currency codes and not knowable here.
                bounds: {},
                rules: [:id, :type, { preferences: {} }, *rule_association_attributes]
              )
            )

            attributes[:rules] = resolved_rule_rows(attributes[:rules]) if attributes.key?(:rules)
            attributes
          end

          private

          # Resolves a rule's product list against this store before it reaches
          # the model. Two things have to happen here and nowhere else: the ids
          # arrive prefixed (only `preferences` are decoded on the way through
          # TypedAssociations), and a product the caller cannot reach must not
          # become part of a rule — a rate could otherwise be narrowed to
          # another marketplace's catalog, and the serializer would read those
          # products' ids straight back.
          #
          # Unreachable ids are dropped rather than refused, matching how
          # delivery-method rules and price-list membership handle the same
          # case: failing the whole save over one stale id would leave a
          # merchant unable to clear it.
          def resolved_rule_rows(rules)
            Array(rules).map do |row|
              row = row.to_h.with_indifferent_access
              next row if row[:product_ids].blank?

              row.merge(product_ids: accessible_product_ids(row[:product_ids]))
            end
          end

          def accessible_product_ids(ids)
            current_store.products.
              accessible_by(current_ability, :show).
              where(id: decode_prefixed_ids(ids)).
              pluck(:id)
          end

          def reject_unregistered_rules
            return false unless params.key?(:rules)

            unknown = Array(params[:rules]).map { |rule| rule[:type].presence }.compact.reject do |type|
              Spree.commission_rules.any? { |klass| klass.api_type == type }
            end
            return false if unknown.empty?

            errors = ActiveModel::Errors.new(Spree::CommissionRate.new)
            unknown.each do |type|
              errors.add(:rules, :invalid, message: Spree.t('errors.messages.invalid_commission_rule_type', type: type))
            end
            render_validation_error(errors)

            true
          end

          # Association-backed config every registered rule kind accepts, so
          # the permit list stays generic. A rule naming catalog-scale records
          # keeps them in its own table rather than its preferences.
          def rule_association_attributes
            Spree.commission_rules.flat_map do |klass|
              klass.additional_permitted_attributes
            end.uniq
          end

          def association_fields_for(klass)
            return [] unless klass.respond_to?(:additional_permitted_attributes)

            klass.additional_permitted_attributes.flat_map do |attribute|
              attribute.is_a?(Hash) ? attribute.keys : attribute
            end.map(&:to_s)
          end
        end
      end
    end
  end
end
