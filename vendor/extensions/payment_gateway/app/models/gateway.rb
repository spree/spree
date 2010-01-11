class Gateway < ActiveRecord::Base
	delegate_belongs_to :provider, :authorize, :purchase, :capture, :void, :credit
	
	validates_presence_of :name, :type

  # instantiates the selected gateway and configures with the options stored in the database
  def self.current
    Gateway.find(:first, :conditions => {:active => true, :environment => ENV['RAILS_ENV']}) 
	end
	
	@provier = nil
  @@providers = Set.new
  def self.register
    @@providers.add(self)
  end

  def self.providers
    @@providers.to_a
  end
  
  def provider_class
    raise "You must implement provider_class method for this gateway."
  end
  
  def provider
    ActiveMerchant::Billing::Base.gateway_mode = server.to_sym
    gateway_options = options
    gateway_options[:test] = true if test_mode
		@provider ||= provider_class.new(gateway_options)
  end 
 
	def validate
		errors.add_to_base I18n.translate("only_one_active_gateway_per_environment") if self.active && Gateway.exists?(["active = ? AND environment = ? AND id <> ?" , true, self.environment, self.id])
	end
 
	def options
	  #self.respond_to? :preferences ? self.preferences : {}
    options_hash = {}
    self.preferences.each do |key,value| 
      #next false if value.nil? || value.empty?    
      options_hash[key.to_sym] = value
    end
    options_hash
    # 
    # options.length == preferences.length ? options : nil
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
  
end
