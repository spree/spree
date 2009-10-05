require File.dirname(__FILE__) + '/sage_core'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageVirtualCheckGateway < Gateway #:nodoc:
      include SageCore
      self.url = 'https://www.sagepayments.net/cgi-bin/eftVirtualCheck.dll?transaction'
      self.source = 'virtual_check'
      
      def purchase(money, credit_card, options = {})
        post = {}
        add_check(post, credit_card)
        add_check_customer_data(post, options)
        add_transaction_data(post, money, options)
        commit(:purchase, post)
      end
      
      def void(reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:void, post)
      end
      
      def credit(money, credit_card, options = {})
        post = {}
        add_check(post, credit_card)
        add_check_customer_data(post, options)
        add_transaction_data(post, money, options)
        commit(:credit, post)
      end
      
      private
      def add_check(post, check)
        post[:C_first_name]   = check.first_name
        post[:C_last_name]    = check.last_name
        post[:C_rte]          = check.routing_number
        post[:C_acct]         = check.account_number
        post[:C_check_number] = check.number
        post[:C_acct_type]    = account_type(check)
      end
      
      def add_check_customer_data(post, options)
        # Required  Customer Type – (NACHA Transaction Class)
        # CCD for Commercial, Merchant Initiated 
        # PPD for Personal, Merchant Initiated
        # WEB for Internet, Consumer Initiated 
        # RCK for Returned Checks 
        # ARC for Account Receivable Entry 
        # TEL for TelephoneInitiated
        post[:C_customer_type] = "WEB"

        # Optional  10  Digit Originator  ID – Assigned  By for  each transaction  class  or  business  purpose. If  not provided, the default Originator ID for the specific  Customer Type will be applied.  
        post[:C_originator_id] = options[:originator_id]

        # Optional  Transaction Addenda
        post[:T_addenda] = options[:addenda]

        # Required  Check  Writer  Social  Security  Number  (  Numbers Only, No Dashes )  
        post[:C_ssn] = options[:ssn].to_s.gsub(/[^\d]/, '')

        post[:C_dl_state_code] = options[:drivers_license_state]
        post[:C_dl_number]     = options[:drivers_license_number]
        post[:C_dob]           = format_birth_date(options[:date_of_birth])
      end
      
      def format_birth_date(date)
        date.respond_to?(:strftime) ? date.strftime("%m/%d/%Y") : date
      end

      # DDA for Checking 
      # SAV for Savings  
      def account_type(check)
        case check.account_type
        when 'checking' then 'DDA'
        when 'savings'  then 'SAV'
        else raise ArgumentError, "Unknown account type #{check.account_type}"
        end
      end
      
      def parse(data)
        response = {}
        response[:success]          = data[1,1]
        response[:code]             = data[2,6].strip
        response[:message]          = data[8,32].strip
        response[:risk]             = data[40, 2]
        response[:reference]        = data[42, 10]
        
        extra_data = data[53...-1].split("\034")
        response[:order_number] = extra_data[0]
        response[:authentication_indicator] = extra_data[1]
        response[:authentication_disclosure] = extra_data[2]
        response
      end
    end
  end
end

