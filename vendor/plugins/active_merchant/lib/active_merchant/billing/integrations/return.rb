module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      class Return
        attr_accessor :params
      
        def initialize(query_string)
          @params = parse(query_string)
        end
      
        # Successful by default. Overridden in the child class
        def success?
          true
        end
      
        def message
          
        end
        
        def parse(query_string)
          return {} if query_string.blank?
          
          query_string.split('&').inject({}) do |memo, chunk|
            next if chunk.empty?
            key, value = chunk.split('=', 2)
            next if key.empty?
            value = value.nil? ? nil : CGI.unescape(value)
            memo[CGI.unescape(key)] = value
            memo
          end
        end 
      end
    end
  end
end
