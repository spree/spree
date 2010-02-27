class Gateway::Beanstream < Gateway
  preference :login, :string
  preference :user, :string
  preference :password, :string
  preference :secure_profile_api_key, :string

  def provider_class
    ActiveMerchant::Billing::BeanstreamGateway
  end

  def payment_profiles_supported?
    true
  end

  def create_profile(creditcard, gateway_options)
    if creditcard.gateway_customer_profile_id.nil?
      options = options_for_create_customer_profile(creditcard, gateway_options)
      verify_creditcard_name!(creditcard)
      result = provider.store(creditcard, options)
      if result.success?
        creditcard.update_attributes(:gateway_customer_profile_id => result.params["customerCode"], :gateway_payment_profile_id => result.params["customer_vault_id"])
      else
        raise "Error creating profile: #{result.message}"
      end
    end
  end
  private
  def verify_creditcard_name!(creditcard)
    bill_address = creditcard.payments.first.payable.bill_address
    creditcard.first_name = bill_address.firstname unless creditcard.first_name?
    creditcard.last_name = bill_address.lastname   unless creditcard.last_name?
  end

  def options_for_create_customer_profile(creditcard, gateway_options)
    checkout = creditcard.payments.first.payable
    address = checkout.bill_address
    { :email=>checkout.email,
      :billing_address=>
      { :name=>address.full_name,
        :phone=>address.phone,
        :address1=>address.address1,
        :address2=>address.address2,
        :city=>address.city,
        :state=>address.state_name || address.state.abbr,
        :country=>address.country.iso,
        :zip=>address.zipcode
      }
    }.merge(gateway_options)
  end

  SECURE_PROFILE_URL = 'https://www.beanstream.com/scripts/payment_profile.asp'
  SP_SERVICE_VERSION = '1.1'
  PROFILE_OPERATIONS = {:new => 'N', :modify => 'M'}

  ActiveMerchant::Billing::BeanstreamGateway.class_eval do

    def store(credit_card, options = {})
      post = {}
      add_address(post, options)
      add_credit_card(post, credit_card)
      add_secure_profile_variables(post,options)
      commit(post, true)
    end

    #can't actually delete a secure profile with the supplicaed API. This function sets the status of the profile to closed (C).
    #Closed profiles will have to removed manually.
    def delete(vault_id)
      update(vault_id, false, {:status => "C"})
    end

    #alias_method :unstore, :delete

    # Update the values (such as CC expiration) stored at
    # the gateway.  The CC number must be supplied in the
    # CreditCard object.
    def update(vault_id, credit_card, options = {})
      post = {}
      add_address(post, options)
      add_credit_card(post, credit_card)
      options.merge!({:vault_id => vault_id, :operation => secure_profile_action(:modify)})
      add_secure_profile_variables(post,options)
      commit(post, true)
    end

    # CORE #

    def secure_profile_action(type)
      PROFILE_OPERATIONS[type] || PROFILE_OPERATIONS[:new]
    end

    def add_credit_card(post, credit_card)
      if credit_card
        if credit_card.has_payment_profile?
          post[:customerCode] = credit_card.gateway_customer_profile_id
        else
          post[:trnCardOwner] = credit_card.name
          post[:trnCardNumber] = credit_card.number
          post[:trnExpMonth] = format(credit_card.month, :two_digits)
          post[:trnExpYear] = format(credit_card.year, :two_digits)
          post[:trnCardCvd] = credit_card.verification_value
        end
      end
    end

    def add_secure_profile_variables(post, options = {})
      post[:serviceVersion] = SP_SERVICE_VERSION
      post[:responseFormat] = 'QS'
      post[:cardValidation] = (options[:cardValidation].to_i == 1) || '0'

      post[:operationType] = options[:operationType] || options[:operation] || secure_profile_action(:new)
      post[:customerCode] = options[:billing_id] || options[:vault_id] || false
      post[:status] = options[:status]
    end

    def commit(params, use_profile_api = false)
      post(post_data(params,use_profile_api),use_profile_api)
    end

    def post(data, use_profile_api)
      response = parse(ssl_post((use_profile_api ? SECURE_PROFILE_URL : ActiveMerchant::Billing::BeanstreamGateway::URL), data))
      response[:customer_vault_id] = response[:customerCode] if response[:customerCode]
      build_response(success?(response), message_from(response), response,
        :test => test? || response[:authCode] == "TEST",
        :authorization => authorization_from(response),
        :cvv_result => ActiveMerchant::Billing::BeanstreamGateway::CVD_CODES[response[:cvdId]],
        :avs_result => { :code => (ActiveMerchant::Billing::BeanstreamGateway::AVS_CODES.include? response[:avsId]) ? ActiveMerchant::Billing::BeanstreamGateway::AVS_CODES[response[:avsId]] : response[:avsId] }
      )
    end

    def message_from(response)
      response[:messageText] || response[:responseMessage]
    end

    def success?(response)
      response[:responseType] == 'R' || response[:trnApproved] == '1' || response[:responseCode] == '1'
    end

    def add_source(post, source)
      if source.is_a?(String) or source.is_a?(Integer)
        post[:customerCode] = source
      else
        source.type.to_s == "check" ? add_check(post, source) : add_credit_card(post, source)
      end
    end

    def post_data(params, use_profile_api)
      params[:requestType] = 'BACKEND'
      if use_profile_api
        params[:merchantId] = @options[:login]
        params[:passCode] = @options[:secure_profile_api_key]
      else
        params[:username] = @options[:user] if @options[:user]
        params[:password] = @options[:password] if @options[:password]
        params[:merchant_id] = @options[:login]
      end
      params[:vbvEnabled] = '0'
      params[:scEnabled] = '0'

      params.reject{|k, v| v.blank?}.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
    end

  end

end
