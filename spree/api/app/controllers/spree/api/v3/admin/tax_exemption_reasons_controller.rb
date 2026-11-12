module Spree
  module Api
    module V3
      module Admin
        class TaxExemptionReasonsController < ResourceController
          scoped_resource :settings

          request_params :tax_exemption_reason do |body|
            body.include_attributes Spree::Api::V3::Admin::ReasonRequestSchema
            body.attribute :code, :string, required: true, on: :create, example: 'RESALE',
              description: 'What the tax provider receives for every certificate holding this reason — for Avalara, an entity use code such as `G`. ' \
                           'Saved in capitals. Changing it changes what those certificates send from then on.'
            body.attribute :metadata, :hash
          end

          protected

          def model_class
            Spree::TaxExemptionReason
          end

          def serializer_class
            Spree.api.admin_tax_exemption_reason_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end

          # The certificate form picks from this list, so staff who manage
          # customers read it without the settings key. Writing stays a
          # settings matter.
          def scoped_resource_name
            reads_through_customers? ? :customers : super
          end

          def scope
            reads_through_customers? ? current_store.tax_exemption_reasons : super
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            return authorize!(:show, Spree::TaxExemptionCertificate) if reads_through_customers?

            super
          end

          def reads_through_customers?
            return @reads_through_customers if defined?(@reads_through_customers)

            @reads_through_customers = action_kind == 'read' &&
                                       !holds_permission?('read_settings') &&
                                       holds_permission?('read_customers')
          end
        end
      end
    end
  end
end
