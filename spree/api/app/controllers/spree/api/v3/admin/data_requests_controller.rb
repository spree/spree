module Spree
  module Api
    module V3
      module Admin
        # The store's log of GDPR data subject requests — what was asked for,
        # by whom, and whether it was answered.
        #
        # Read-only plus create. A request is a record of something that
        # happened, so editing one would falsify the audit trail the record
        # exists to provide; erasing the log of an erasure is worse still.
        class DataRequestsController < ResourceController
          scoped_resource :customers

          def create
            authorize! :create, Spree::DataRequest

            result = Spree::DataRequests::Create.call(
              store: current_store,
              customer: customer,
              kind: params[:kind],
              requested_by: try_spree_current_user
            )

            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value), status: :accepted
          end

          protected

          def model_class
            Spree::DataRequest
          end

          def serializer_class
            Spree.api.admin_data_request_serializer
          end

          def scope
            super.recent_first
          end

          def collection_includes
            [:customer]
          end

          private

          # Customers are global in Spree — they shop across a multi-store
          # installation on one account — so there is no store association to
          # narrow this through. `authorize!` above is what gates the caller,
          # and the request records which store it was raised at.
          def customer
            @customer ||= Spree.customer_class.find_by_prefix_id!(params[:customer_id])
          end
        end
      end
    end
  end
end
