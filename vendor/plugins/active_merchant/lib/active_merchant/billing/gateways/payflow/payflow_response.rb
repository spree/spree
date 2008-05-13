module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowResponse < Response
      def profile_id
        @params['profile_id']
      end
      
      def payment_history
        @payment_history ||= @params['rp_payment_result'].collect{ |result| result.stringify_keys } rescue []
      end
    end
  end
end