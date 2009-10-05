module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module TwoCheckout
        class Return < ActiveMerchant::Billing::Integrations::Return
          def success?
            params['credit_card_processed'] == 'Y'
          end
          
          def message
            
          end
	      end
      end
    end
  end
end
