require 'date'

module ActiveMerchant
  module Billing
    class CreditCard
      class ExpiryDate #:nodoc:
        attr_reader :month, :year
        def initialize(month, year)
          @month = month.to_i
          @year = year.to_i
        end
        
        def expired? #:nodoc:
          Time.now.utc > expiration
        end
        
        def expiration #:nodoc:
          begin
            Time.utc(year, month, month_days, 23, 59, 59)
          rescue ArgumentError
            Time.at(0).utc
          end
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