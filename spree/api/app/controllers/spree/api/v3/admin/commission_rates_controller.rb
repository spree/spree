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
          # `value` is a percentage, a name too general to be in StrictMoneyParams' list.
          before_action -> { decimal_param(:value) }, only: %i[create update]
          scoped_resource :commissions

          request_params :commission_rate do
            string :name, required: :create, example: 'Audio sellers'
            string :code, nullable: true, example: 'audio',
                          description: 'Your own identifier for this rate; unique per store.'
            boolean :enabled
            integer :position, example: 1,
                               description: 'Place in the list. Rates resolve top-down and the first whose rules match wins, so 1 is tried first. New rates are created at the top; send this to move one. A rate with no rules matches every sale, so the marketplace default belongs at the bottom.'
            string :kind, required: :create, enum: Spree::CommissionRate::KINDS, example: 'percentage',
                          description: '`percentage` charges a share of the sale; `fixed` charges a flat fee.'
            decimal :value, required: :create, example: '12.5',
                            description: 'A percentage (10 = 10%) or a flat amount, per `kind`.'
            boolean :tax_inclusive,
                    description: "Charge on the price including the customer's VAT. Left off, commission is charged on the seller's net revenue, which is the usual basis where the fee is taxed as its own supply."
            boolean :include_shipping,
                    description: "Also charge commission on the seller's delivery revenue. Percentage rates only."
            decimal :commission_tax_rate, nullable: true, example: '0.21',
                                          description: "VAT on the commission itself, as a fraction rather than a percentage. Null lets the store's tax engine answer for the seller's jurisdiction."
            object :metadata
            object :amounts, example: { USD: '2.50', EUR: '2.00' },
                             description: 'What a flat fee charges, keyed by currency, as decimal strings. A sale in a currency with no amount falls to the next matching rate. Replaces the whole set.'
            object :bounds, example: { USD: { min_amount: '1.00', max_amount: '50.00' } },
                            description: 'The floor and cap a percentage charges within, keyed by currency: `{ min_amount, max_amount }` decimal strings. A sale in a currency with no bounds is charged unbounded. Replaces the whole set.'
            # Permitted in `permitted_params`, with the keys each registered
            # rule kind adds.
            object :rules, array: true, permit: false, as: 'CommissionRuleDraftParams',
                           description: 'The full targeting; what you send replaces what the rate holds.' do
              id :id, nullable: true, description: 'Present for an existing rule; omit to create one.'
              string :type, required: true, example: 'seller_rule',
                            description: 'A kind from `GET /commission_rates/rule_types`.'
              object :preferences, example: { seller_ids: ['sel_a1b2c3'] },
                                   description: "Configuration for the kind, per its type's `schema`."
              id :product_ids, array: true,
                               description: 'For kinds that name products, which are kept outside preferences.'
            end
          end

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
                description: klass.human_description,
                schema: klass.preference_json_schema,
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
            super.ordered
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
              params.permit(*declared_permitted_attributes,
                            rules: [:id, :type, { preferences: {} }, *rule_association_attributes])
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
              errors.add(:rules, :invalid_commission_rule_type, type: type,
                         message: I18n.t('spree.errors.messages.invalid_commission_rule_type', type: type))
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
            case klass.api_type
            when 'seller_rule' then ['seller_ids']
            when 'category_rule' then ['category_ids']
            else
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
end
