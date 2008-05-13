require File.dirname(__FILE__) + '/payflow_nv/payflow_nv_common_api'
require File.dirname(__FILE__) + '/payflow_nv/payflow_nv_response'
require File.dirname(__FILE__) + '/payflow_express_nv'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowNvGateway < Gateway
      include PayflowNvCommonAPI

      RECURRING_ACTIONS = Set.new([:add, :modify, :cancel, :inquiry, :reactivate, :payment])
      TERM_PERIOD = Set.new([:week, :biwk, :smmo, :frwk, :mont, :qter, :smyr, :year])

      RECURRING_CODE = {
        :add        => "A",
        :modify     => "M",
        :cancel     => "C",
        :inquiry    => "I",
        :reactivate => "R",
        :payment    => "P",
      }

      self.supported_cardtypes = [:visa, :master, :american_express, :jcb, :discover, :diners_club]
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=_payflow-pro-overview-outside'
      self.display_name = 'PayPal Payflow Pro'

      def authorize(money, credit_card_or_reference, options = {})
        post = build_sale_or_authorization_request(money, credit_card_or_reference, options)
        commit(:authorization, post)
      end

      def purchase(money, credit_card_or_reference, options = {})
        if credit_card_or_reference.is_a?(String)
          post = build_reference_sale_or_authorization_request(money, credit_card_or_reference, options)
        else
          post = build_sale_or_authorization_request(money, credit_card_or_reference, options)
        end
        commit(:purchase, post)
      end

      def build_reference_sale_or_authorization_request(money, reference, options)
        post = {}
        add_reference(post, reference, options)
        add_amount(post, money, options)
        return post
      end

      def build_sale_or_authorization_request(money, credit_card_or_reference, options)
        post = {}
        add_addresses(post, options)
        add_customer_data(post, options)
        add_invoice(post, options)
        add_credit_card(post, credit_card_or_reference)
        add_amount(post, money, options)
        post
      end

      public

      def credit(money, identification_or_credit_card, options = {})
        if identification_or_credit_card.is_a?(String)
          # Perform referenced credit
          post = build_reference_request(money, identification_or_credit_card, options)
        else
          # Perform non-referenced credit
          post = build_credit_card_request(money, identification_or_credit_card, options)
        end

        commit(:credit, post)
      end

      # Adds or modifies a recurring Payflow profile.  See the Payflow Pro Recurring Billing Guide for more details:
      # https://www.paypal.com/en_US/pdf/PayflowPro_RecurringBilling_Guide.pdf
      #
      # Several options are available to customize the recurring profile:
      #
      # * <tt>profile_id</tt> - is only required for editing a recurring profile
      # * <tt>starting_at</tt> - takes a Date, Time, or string in mmddyyyy format. The date must be in the future.
      # * <tt>name</tt> - The name of the customer to be billed.  If not specified, the name from the credit card is used.
      # * <tt>periodicity</tt> - The frequency that the recurring payments will occur at.  Can be one of
      # :bimonthly, :monthly, :biweekly, :weekly, :yearly, :daily, :semimonthly, :quadweekly, :quarterly, :semiyearly
      # * <tt>payments</tt> - The term, or number of payments that will be made
      # * <tt>comment</tt> - A comment associated with the profile
      def recurring(money, credit_card, options = {})
        options[:name] = credit_card.name if options[:name].blank? && credit_card
        post = build_recurring_request(options[:profile_id] ? :modify : :add, money, options)
        add_credit_card(post, credit_card) if credit_card
        commit(:recurring, post)
      end

      def cancel_recurring(profile_id)
        post = build_recurring_request(:cancel, 0, :profile_id => profile_id)
        commit(:recurring, post)
      end

      def recurring_inquiry(profile_id, options = {})
        post = build_recurring_request(:inquiry, nil, options.update( :profile_id => profile_id ))
        commit(:recurring, post)
      end

      def express
        @express ||= PayflowExpressNvGateway.new(@options)
      end


      private
      def build_credit_card_request(money, credit_card, options)
        post = {}
        add_credit_card(post, credit_card)
        add_amount(post, money, options)
        return post
      end

      def add_credit_card(post, credit_card)
        post[:tender] = TENDERS[:credit_card]
        post[:firstname]  = credit_card.first_name
        post[:lastname]   = credit_card.last_name
        post[:acct]       = credit_card.number
        post[:expdate]    = format_date(credit_card.month, credit_card.year)
        post[:cvv2] = credit_card.verification_value if credit_card.verification_value?
        if [ 'switch', 'solo' ].include?(credit_card.type.to_s)
          post[:cardstart] = format_date(credit_card.start_month, credit_card.start_year) unless credit_card.start_month.blank? || credit_card.start_year.blank?
          post[:cardissue] = credit_card.issue_number unless credit_card.issue_number.blank?
        end
      end

      def format_date(month, year)
        month = format(month, :two_digits)
        year  = format(year, :two_digits)

        "#{month}#{year}"
      end

      def credit_card_type(credit_card)
        return '' if card_brand(credit_card).blank?

        CARD_MAPPING[card_brand(credit_card).to_sym]
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{year}#{month}"
      end

      def startdate(creditcard)
        year  = format(creditcard.start_year, :two_digits)
        month = format(creditcard.start_month, :two_digits)

        "#{month}#{year}"
      end



      # Number of payments to be made over the agreement
      # 0 = payments made until profile deactivated
      def add_term(post, options)
        post[:term] = options[:term] || 0
      end

      def build_recurring_request(action, money, options)
        unless RECURRING_ACTIONS.include?(action)
          raise StandardError, "Invalid Recurring Profile Action: #{action}"
        end


        post = {}
        add_pair(post, :action, RECURRING_CODE[action])
        unless [:cancel, :inquiry].include?(action)
          # Requirements
          #requires!(options, [:profilename])


          # Construct messages
          add_amount(post, money, options)
          add_pair(post, :profilename, (options[:profilename]||"foo"))
          add_pair(post, :name, options[:name]) unless options[:name].nil?
          add_amount(post, money, options)
          add_pair(post, :payperiod, get_pay_period(options))
          add_term(post, options[:payments]) unless options[:payments].nil?
          add_pair(post, :comment, options[:comment]) unless options[:payments].nil?
          add_pair(post, :start,  format_rp_date(options[:starting_at] || Date.today + 1 ))
          add_pair(post, :email, options[:email]) unless options[:email].nil?

          if initial_tx = options[:initial_transaction]
            requires!(initial_tx, [:type, :authorization, :purchase])
            requires!(initial_tx, :amount) if initial_tx[:type] == :purchase

            add_pair(post, 'OptionalTrans', TRANSACTIONS[initial_tx[:type]])
            add_pair(post, 'OptionalTransAmt', amount(initial_tx[:amount])) unless initial_tx[:amount].blank?
          end
          add_addresses(post, options)
        end

        if action != :add
          add_pair(post, :origprofileid, options[:profile_id])
        end

        if action == :inquiry
          add_pair(post, :paymenthistory, options[:history] ? 'Y' : 'N' )
        end
        return post
      end


      def get_pay_period(options)
        requires!(options, [:periodicity, :bimonthly, :monthly, :biweekly, :weekly, :yearly, :daily, :semimonthly, :quadweekly, :quarterly, :semiyearly])
        case options[:periodicity]
          when :weekly then 'WEEK'
          when :biweekly then 'BIWK'
          when :semimonthly then 'SMMO'
          when :quadweekly then 'FRWK'
          when :monthly then 'MONT'
          when :quarterly then 'QTER'
          when :semiyearly then 'SMYR'
          when :yearly then 'YEAR'
        end
      end

      def format_rp_date(time)
        case time
          when Time, Date then time.strftime("%m%d%Y")
        else
          time.to_s
        end
      end

      def build_response(success, message, response, options = {})
        PayflowNvResponse.new(success, message, response, options)
      end
    end
  end
end

