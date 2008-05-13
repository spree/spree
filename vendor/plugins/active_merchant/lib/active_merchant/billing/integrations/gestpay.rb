# With help from Giovanni Intini and his code for RGestPay - http://medlar.it/it/progetti/rgestpay

require File.dirname(__FILE__) + '/gestpay/common.rb'
require File.dirname(__FILE__) + '/gestpay/helper.rb'
require File.dirname(__FILE__) + '/gestpay/notification.rb'
require File.dirname(__FILE__) + '/gestpay/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Gestpay 
       
        mattr_accessor :service_url
        self.service_url = 'https://ecomm.sella.it/gestpay/pagam.asp'

        def self.notification(post)
          Notification.new(post)
        end  
        
        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
