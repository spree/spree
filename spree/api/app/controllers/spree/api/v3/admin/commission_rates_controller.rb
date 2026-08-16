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
        # vendor audience, because a seller must never see, let alone set, what
        # anyone is charged.
        class CommissionRatesController < ResourceController
          scoped_resource :commissions

          # GET /api/v3/admin/commission_rates/rule_subject_types
          #
          # What a rule may target, so the dashboard can build its picker
          # without hardcoding a list that core owns.
          def rule_subject_types
            authorize! :read, Spree::CommissionRule

            render json: {
              data: Spree::CommissionRule::SUBJECT_TYPES.map do |subject_type|
                {
                  type: subject_type,
                  name: Spree.t("commission_rule_subjects.#{subject_type.demodulize.underscore}",
                                default: subject_type.demodulize.titleize)
                }
              end
            }
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
            [{ commission_rules: :subject }]
          end

          # `rule_subject_types` is read-only discovery — maps to the read
          # scope and the :show ability rather than counting as a write.
          def read_actions
            super + %w[rule_subject_types]
          end

          def permitted_params
            attributes = normalize_params(
              params.permit(
                :name, :code, :enabled, :priority, :kind, :value, :currency,
                :include_tax, :include_shipping, :min_amount, :max_amount, :commission_tax_rate,
                metadata: {},
                rules: [:subject_type, :subject_id]
              )
            )

            attributes[:rules] = own_store_rules(attributes[:rules]) if attributes.key?(:rules)
            attributes
          end

          private

          # Drops any rule naming a record this store does not own.
          #
          # The model assigns rule subjects by id with no scoping of its own, so
          # without this a rate could be targeted at another store's product —
          # and the serializer would then read that record's name straight back,
          # which is an enumeration oracle over someone else's catalog.
          def own_store_rules(rules)
            Array(rules).select do |rule|
              subject_type = rule[:subject_type].presence
              next true if subject_type.nil? && rule[:subject_id].blank?
              next false unless Spree::CommissionRule::SUBJECT_TYPES.include?(subject_type)

              own_store_subject?(subject_type, rule[:subject_id])
            end
          end

          def own_store_subject?(subject_type, subject_id)
            return false if subject_id.blank?

            case subject_type
            when 'Spree::Product' then current_store.products.exists?(id: subject_id)
            when 'Spree::Vendor' then current_store.vendors.exists?(id: subject_id)
            # Categories are store-owned too, and reached the same way.
            when 'Spree::Category' then current_store.categories.exists?(id: subject_id)
            else false
            end
          end
        end
      end
    end
  end
end
