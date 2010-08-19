class Gateway < PaymentMethod
	delegate_belongs_to :provider, :authorize, :purchase, :capture, :void, :credit
	
	validates :name, :type, :presence => true
  
  preference :server, :string, :default => 'test'
  preference :test_mode, :boolean, :default => true

  def payment_source_class
    Creditcard
  end
  
  # instantiates the selected gateway and configures with the options stored in the database
  def self.current
    super
	end	
  
  def provider
    gateway_options = options
    ActiveMerchant::Billing::Base.gateway_mode = gateway_options[:server].to_sym
    @provider ||= provider_class.new(gateway_options)
  end 
 
	def options
    options_hash = {}
    self.preferences.each do |key,value| 
      options_hash[key.to_sym] = value
    end
    options_hash
	end
	
	def method_missing(method, *args)
	 	if @provider.nil?
			super
		else
			@provider.respond_to?(method) ? provider.send(method) : super
		end
	end
	
	def payment_profiles_supported?
	  false
  end
  
  def method_type
    "gateway"
  end
  
end
