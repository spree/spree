module ActiveMerchant
  module Billing
    class CreditCard
      class ExpiryDate #:nodoc:
        attr_reader :month, :year
        def initialize(month, year)
          @month = month
          @year = year
        end
        
        def expired? #:nodoc:
          Time.now > expiration rescue true
        end
        
        def expiration #:nodoc:
          Time.parse("#{month}/#{month_days}/#{year} 23:59:59") rescue Time.at(0)
        end
        
        private
        def month_days
          mdays = [nil,31,28,31,30,31,30,31,31,30,31,30,31]
          mdays[2] = 29 if Date.leap?(year)
          mdays[month]
        end
      end
    end
  end
end