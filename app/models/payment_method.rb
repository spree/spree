class PaymentMethod < ActiveRecord::Base
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
end