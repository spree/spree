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
  
  # The class that will process payments for this payment type, used for @payment.source
  # e.g. Creditcard in the case of a the Gateway payment type
  def payment_source_class
    raise "You must implement payment_source_class method for this gateway."
  end

  def self.available    
    PaymentMethod.all.select { |p| p.active and (p.environment == ENV['RAILS_ENV'] or p.environment.blank?) }
	end    

  def method_type
    type.demodulize.downcase
  end
  

end