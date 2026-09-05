module Spree
  module Api
    module V3
      module Store
        module Customer
          # A customer exercising their own GDPR rights: a copy of their data
          # (Art. 15) or its erasure (Art. 17).
          #
          # Erasure asks for the account password. Wiping a person's history is
          # irreversible, and an unattended session should not be enough to
          # trigger it — the same bar the account already applies to changing
          # an email address.
          class DataRequestsController < ResourceController
            include Spree::Api::V3::CurrentPasswordConfirmation

            prepend_before_action :require_authentication!

            # POST /api/v3/store/customers/me/data_requests
            def create
              return render_current_password_invalid if erasure? && !valid_current_password?

              result = Spree::DataRequests::Create.call(
                store: current_store,
                customer: current_user,
                kind: requested_kind
              )

              return render_result_error(result) unless result.success?

              # 202: the request is accepted and the work happens elsewhere.
              # Answering 201 would imply the export already exists.
              render json: serialize_resource(result.value), status: :accepted
            end

            protected

            def model_class
              Spree::DataRequest
            end

            def serializer_class
              Spree.api.data_request_serializer
            end

            def set_parent
              @parent = current_user
            end

            def parent_association
              :data_requests
            end

            # A person sees their own requests and no one else's. The store
            # narrowing is restated because the parent branch of the base scope
            # replaces `for_store` with the association, and a customer is
            # global while their requests are not.
            def scope
              super.for_store(current_store).recent_first
            end

            private

            # Anything that is not an explicit erasure is a request to read —
            # the safe reading of an ambiguous parameter.
            def requested_kind
              erasure? ? Spree::DataRequest::ERASURE : Spree::DataRequest::ACCESS
            end

            def erasure?
              params[:kind].to_s == Spree::DataRequest::ERASURE
            end

          end
        end
      end
    end
  end
end
