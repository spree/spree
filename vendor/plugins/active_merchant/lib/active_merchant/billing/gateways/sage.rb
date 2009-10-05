require File.dirname(__FILE__) + '/sage/sage_bankcard'
require File.dirname(__FILE__) + '/sage/sage_virtual_check'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageGateway < Gateway
      self.supported_countries = SageBankcardGateway.supported_countries
      self.supported_cardtypes = SageBankcardGateway.supported_cardtypes

      # Creates a new SageGateway
      # 
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      # 
      # ==== Options
      #
      # * <tt>:login</tt> - The Sage Payment Solutions Merchant ID Number.
      # * <tt>:password</tt> - The Sage Payment Solutions Merchant Key Number.
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      # Performs an authorization transaction
      # 
      # ==== Parameters
      # * <tt>money</tt> - The amount to be authorized as an integer value in cents.
      # * <tt>credit_card</tt> - The CreditCard object to be used as the funding source for the transaction.
      # * <tt>options</tt> - A hash of optional parameters.
      #   * <tt>:order_id</tt> - A unique reference for this order. (maximum of 20 characters).
      #   * <tt>:email</tt> - The customer's email address
      #   * <tt>:customer</tt> - The Customer Number for Purchase Card Level II Transactions
      #   * <tt>:billing_address</tt> - The customer's billing address as a hash of address information.
      #     * <tt>:address1</tt> - The billing address street
      #     * <tt>:city</tt> - The billing address city
      #     * <tt>:state</tt> - The billing address state
      #     * <tt>:country</tt> - The 2 digit ISO billing address country code
      #     * <tt>:zip</tt> - The billing address zip code
      #     * <tt>:phone</tt> - The billing address phone number
      #     * <tt>:fax</tt> - The billing address fax number
      #   * <tt>:shipping_address</tt> - The customer's shipping address as a hash of address information.
      #     * <tt>:name</tt> - The name at the shipping address 
      #     * <tt>:address1</tt> - The shipping address street
      #     * <tt>:city</tt> - The shipping address city
      #     * <tt>:state</tt> - The shipping address state code
      #     * <tt>:country</tt> - The 2 digit ISO shipping address country code
      #     * <tt>:zip</tt> - The shipping address zip code
      #   * <tt>:tax</tt> - The tax amount for the transaction as an Integer value in cents. Maps to Sage <tt>T_tax</tt>.
      #   * <tt>:shipping</tt> - The shipping amount for the transaction as an Integer value in cents. Maps to Sage <tt>T_shipping</tt>.      
      def authorize(money, credit_card, options = {})
        bankcard.authorize(money, credit_card, options)
      end
      
      # Performs a purchase, which is essentially an authorization and capture in a single operation.
      # 
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be authorized as an integer value in cents.
      # * <tt>source</tt> - The CreditCard or Check object to be used as the funding source for the transaction.
      # * <tt>options</tt> - A hash of optional parameters.
      #   * <tt>:order_id</tt> - A unique reference for this order. (maximum of 20 characters).
      #   * <tt>:email</tt> - The customer's email address
      #   * <tt>:customer</tt> - The Customer Number for Purchase Card Level II Transactions
      #   * <tt>:billing_address</tt> - The customer's billing address as a hash of address information.
      #     * <tt>:address1</tt> - The billing address street
      #     * <tt>:city</tt> - The billing address city
      #     * <tt>:state</tt> - The billing address state
      #     * <tt>:country</tt> - The 2 digit ISO billing address country code
      #     * <tt>:zip</tt> - The billing address zip code
      #     * <tt>:phone</tt> - The billing address phone number
      #     * <tt>:fax</tt> - The billing address fax number
      #   * <tt>:shipping_address</tt> - The customer's shipping address as a hash of address information.
      #     * <tt>:name</tt> - The name at the shipping address 
      #     * <tt>:address1</tt> - The shipping address street
      #     * <tt>:city</tt> - The shipping address city
      #     * <tt>:state</tt> - The shipping address state code
      #     * <tt>:country</tt> - The 2 digit ISO shipping address country code
      #     * <tt>:zip</tt> - The shipping address zip code
      #   * <tt>:tax</tt> - The tax amount for the transaction as an integer value in cents. Maps to Sage <tt>T_tax</tt>.
      #   * <tt>:shipping</tt> - The shipping amount for the transaction as an integer value in cents. Maps to Sage <tt>T_shipping</tt>.
      #
      # ==== Additional options in the +options+ hash for when using a Check as the funding source
      # * <tt>:originator_id</tt> - 10 digit originator. If not provided, Sage will use the default Originator ID for the specific customer type.
      # * <tt>:addenda</tt> - Transaction addenda.
      # * <tt>:ssn</tt> - The customer's Social Security Number.
      # * <tt>:drivers_license_state</tt> - The customer's drivers license state code.
      # * <tt>:drivers_license_number</tt> - The customer's drivers license number.
      # * <tt>:date_of_birth</tt> - The customer's date of birth as a Time or Date object or a string in the format <tt>mm/dd/yyyy</tt>.
      def purchase(money, source, options = {})
        if source.type == "check"
          virtual_check.purchase(money, source, options)
        else
          bankcard.purchase(money, source, options)
        end
      end                       
    
      # Captures authorized funds.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be authorized as an integer value in cents. Sage doesn't support changing the capture amount, so the full amount of the initial transaction will be captured.
      # * <tt>reference</tt> - The authorization reference string returned by the original transaction's Response#authorization.
      def capture(money, reference, options = {})
        bankcard.capture(money, reference, options)
      end
      
      # Voids a prior transaction. Works for both CreditCard and Check transactions.
      #
      # ==== Parameters
      #
      # * <tt>reference</tt> - The authorization reference string returned by the original transaction's Response#authorization.
      def void(reference, options = {})
        if reference.split(";").last == "virtual_check"
          virtual_check.void(reference, options)
        else
          bankcard.void(reference, options)
        end
      end

      # Performs a credit transaction. (Sage +Credit+ transaction).
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be authorized as an integer value in cents.
      # * <tt>source</tt> - The CreditCard or Check object to be used as the target for the credit.
      def credit(money, source, options = {})
        if source.type == "check"
          virtual_check.credit(money, source, options)
        else
          bankcard.credit(money, source, options)
        end
      end
          
      private
      def bankcard
        @bankcard ||= SageBankcardGateway.new(@options)
      end
      
      def virtual_check
        @virtual_check ||= SageVirtualCheckGateway.new(@options)
      end 
    end
  end
end

