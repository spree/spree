module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowExpressResponse < Response
      def email
        @params['e_mail']
      end
      
      def full_name
        "#{@params['name']} #{@params['lastname']}"
      end
      
      def token
        @params['token']
      end
      
      def payer_id
        @params['payer_id']
      end
      
      # Really the shipping country, but it is all the information provided
      def payer_country
        address['country']
      end
      
      def address
        {  'name'       => full_name,
           'company'    => nil,
           'address1'   => @params['street'],
           'address2'   => nil,
           'city'       => @params['city'],
           'state'      => @params['state'],
           'country'    => @params['country'],
           'zip'        => @params['zip'],
           'phone'      => nil
        }
      end
    end
  end
end