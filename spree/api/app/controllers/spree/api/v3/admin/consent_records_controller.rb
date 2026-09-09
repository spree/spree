module Spree
  module Api
    module V3
      module Admin
        # The evidence trail behind a customer's consent state — what was
        # agreed, when, from where, and which document version was shown.
        #
        # Read-only. GDPR Art. 7(1) asks the controller to demonstrate that
        # consent was given, and a record an operator can edit demonstrates
        # nothing.
        class ConsentRecordsController < ResourceController
          scoped_resource :customers

          protected

          def model_class
            Spree::ConsentRecord
          end

          def serializer_class
            Spree.api.admin_consent_record_serializer
          end

          def scope
            super.recent_first
          end
        end
      end
    end
  end
end
