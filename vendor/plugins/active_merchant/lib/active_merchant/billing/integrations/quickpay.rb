require File.dirname(__FILE__) + '/quickpay/helper.rb'
require File.dirname(__FILE__) + '/quickpay/notification.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Quickpay 
       
        mattr_accessor :service_url
        self.service_url = 'https://secure.quickpay.dk/form/'

        def self.notification(post)
          Notification.new(post)
        end  
      end
    end
  end
end
