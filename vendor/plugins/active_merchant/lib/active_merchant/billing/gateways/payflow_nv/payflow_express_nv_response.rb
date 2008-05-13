module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowExpressNvResponse < Response
      def email
        @params['email']
      end

      def full_name
        "#{@params['firstname']} #{@params['lastname']}"
      end

      def token
        @params['token']
      end

      def payer_id
        @params['payerid']
      end

      # Really the shipping country, but it is all the information provided
      def payer_country
        address['country']
      end

      def address
        {  'name'       => full_name,
           'company'    => @params['business'],
           'address1'   => @params['shiptostreet'],
           'address2'   => nil,
           'city'       => @params['shiptocity'],
           'state'      => @params['shiptostate'],
           'country'    => @params['shiptocountry'],
           'zip'        => @params['shiptozip'],
           'phone'      => nil
        }
      end
    end
  end
end
