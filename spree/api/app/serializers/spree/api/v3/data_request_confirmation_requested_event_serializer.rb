module Spree
  module Api
    module V3
      # The event shape for `data_request.confirmation_requested`: what a
      # storefront that sends its own emails needs to ask the person to confirm
      # a request they raised. `confirmation_token` is a live credential, so
      # the event reaches only endpoints that name it.
      class DataRequestConfirmationRequestedEventSerializer < DataRequestEventSerializer
        typelize email: :string, confirmation_token: :string, store_id: :string,
                 redirect_url: [:string, optional: true]

        attributes :email

        attribute :confirmation_token do
          params[:confirmation_token]
        end

        attribute :store_id do |data_request|
          data_request.store.prefixed_id
        end

        attribute :redirect_url, if: proc { params[:redirect_url].present? } do
          params[:redirect_url]
        end
      end
    end
  end
end
