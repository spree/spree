module Spree
  module DataRequests
    # Confirms a request the customer raised, from the link emailed to the
    # address it names, and queues the work.
    #
    # Confirming again is answered with the request as it stands, so a second
    # click on the same link changes nothing.
    class Confirm
      prepend Spree::ServiceModule::Base

      # @param data_request [Spree::DataRequest]
      # @return [Spree::ServiceModule::Result] the confirmed request
      def call(data_request:)
        newly_confirmed = false

        data_request.with_lock do
          newly_confirmed = data_request.confirmable?

          if newly_confirmed
            data_request.update!(status: 'pending')
          elsif data_request.awaiting_confirmation?
            data_request.update!(status: 'lapsed')
          end
        end

        if data_request.lapsed?
          data_request.errors.add(:base, I18n.t('spree.data_request_errors.confirmation_invalid'))
          return failure(data_request)
        end

        Spree::DataRequests::ProcessJob.perform_later(data_request.prefixed_id) if newly_confirmed

        success(data_request)
      end
    end
  end
end
