module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowNvResponse < Response
      def profile_id
        @params['profileid']
      end

      def payment_history
        @payment_history ||= get_history
      end
      protected
      def get_history
        hist = []
        @params.reject {|key,val| key !~ /p_result/}.collect {|r| r[0].gsub(/p_result/, "")}.sort.each do |idx|
          item = {
            'payment_num' => "#{idx}",
            'amt' => @params["p_amt#{idx}"],
            'transtime' => @params["p_transtime#{idx}"],
            'result' => @params["p_result#{idx}"],
            'state' => @params["p_transtate#{idx}"],
          }
          hist << item
        end
        return hist
      end
    end
  end
end
