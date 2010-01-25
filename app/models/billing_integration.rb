class BillingIntegration < ActiveRecord::Base

  def self.current
    self.first :conditions => ["environment = ? AND active = ?", RAILS_ENV, true]
  end

  validates_presence_of :name, :type

  @provier = nil
  @@providers = Set.new
  def self.register
    @@providers.add(self)
  end

  def self.providers
    @@providers.to_a
  end

  def provider_class
    raise "You must implement provider_class method for this billing integration."
  end

  def provider
    ActiveMerchant::Billing::Base.integration_mode = server.to_sym
    integration_options = options
    integration_options[:test] = true if test_mode
    @provider ||= provider_class.new(integration_options)
  end

  def validate
    errors.add_to_base I18n.translate("only_one_active_gateway_per_environment") if self.active && BillingIntegration.exists?(["active = ? AND environment = ? AND id <> ?" , true, self.environment, self.id])
  end

  def options
    options_hash = {}
    self.preferences.each do |key,value|
      options_hash[key.to_sym] = value
    end
    options_hash
  end
end
