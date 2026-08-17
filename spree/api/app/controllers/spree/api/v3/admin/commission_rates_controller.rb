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

          def create
            return if reject_unreachable_rules

            super
          end

          def update
            return if reject_unreachable_rules

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
                :name, :code, :enabled, :position, :kind, :value, :currency,
                :tax_inclusive, :include_shipping, :min_amount, :max_amount, :commission_tax_rate,
                metadata: {},
                rules: [:subject_type, :subject_id]
              )
            )

            attributes
          end

          private

          # Refuses a payload naming anything this store does not own, and
          # answers whether it did so the action can stop before the write.
          #
          # Rejected rather than filtered, because `rules` replaces a rate's
          # whole targeting: quietly dropping the bad rows would leave a rate
          # with no rules, and a rate with no rules charges every seller on the
          # marketplace. A client sending one stale id would silently widen what
          # it meant to narrow, and get a 200 saying so.
          #
          # The model resolves subjects by id with no scoping of its own, so
          # this is also what stops a rate being pointed at another store's
          # catalog — the serializer reads the subject's name straight back,
          # which would otherwise enumerate it.
          def reject_unreachable_rules
            unreachable = unreachable_rules
            return false if unreachable.empty?

            errors = ActiveModel::Errors.new(Spree::CommissionRate.new)
            unreachable.each do |rule|
              errors.add(:rules, :not_found, message: rules_error_message(rule))
            end
            render_validation_error(errors)

            true
          end

          def rules_error_message(rule)
            subject_type = rule[:subject_type].presence

            if subject_type.blank? || !Spree::CommissionRule::SUBJECT_TYPES.include?(subject_type)
              Spree.t('errors.messages.commission_rule_subject_type_unknown', type: subject_type.presence || '')
            else
              Spree.t('errors.messages.commission_rule_subject_not_found',
                      type: subject_type, id: rule[:subject_id])
            end
          end

          def unreachable_rules
            return [] unless params.key?(:rules)

            Array(params[:rules]).reject do |rule|
              subject_type = rule[:subject_type].presence
              next true if subject_type.nil? && rule[:subject_id].blank?
              next false unless Spree::CommissionRule::SUBJECT_TYPES.include?(subject_type)

              own_store_subject?(subject_type, decode_subject_id(rule[:subject_id]))
            end
          end

          # Ids arrive prefixed; `normalize_params` decodes them on the way to
          # assignment, but this check reads the raw payload.
          def decode_subject_id(value)
            return value if value.blank?

            prefixed_id?(value) ? decode_prefixed_id(value) : value
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
