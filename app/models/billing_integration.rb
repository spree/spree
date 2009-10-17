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
end
