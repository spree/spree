require File.dirname(__FILE__) + '/beanstream/beanstream_core'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BeanstreamInteracResponse < Response
      def redirect
        params['pageContents']
      end
    end
    
    class BeanstreamInteracGateway < Gateway
      include BeanstreamCore
      
      # Confirm a transaction posted back from the bank to Beanstream.
      # Confirming a transaction does not require any credentials,
      # and in an application with many merchants sharing a funded
      # URL the application may not yet know which merchant the 
      # post back is for until the response of the confirmation is
      # received, which contains the order number.
      def self.confirm(transaction)
        gateway = new(:login => '')
        gateway.confirm(transaction)
      end
      
      def purchase(money, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_address(post, options)
        add_interac_details(post, options)
        add_transaction_type(post, :purchase)
        commit(post)
      end
      
      # Confirm a transaction posted back from the bank to Beanstream.
      def confirm(transaction)
        post(transaction)
      end
      
      private
      
      def add_interac_details(post, options)
        address = options[:billing_address] || options[:address] || {}
        post[:trnCardOwner] = address[:name]
        post[:paymentMethod] = 'IO'
      end
      
      def build_response(*args)
        BeanstreamInteracResponse.new(*args)
      end
    end
  end
end

