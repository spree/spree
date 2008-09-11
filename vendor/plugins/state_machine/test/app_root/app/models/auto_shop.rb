class AutoShop < ActiveRecord::Base
  state_machine :state, :initial => 'available' do
    after_transition :from => 'available', :do => :increment_customers
    after_transition :from => 'busy', :do => :decrement_customers
    
    event :tow_vehicle do
      transition :to => 'busy', :from => 'available'
    end
    
    event :fix_vehicle do
      transition :to => 'available', :from => 'busy'
    end
  end
  
  # Is the Auto Shop available for new customers?
  def available?
    state == 'available'
  end
  
  # Is the Auto Shop currently not taking new customers?
  def busy?
    state == 'busy'
  end
  
  # Increments the number of customers in service
  def increment_customers
    update_attribute(:num_customers, num_customers + 1)
  end
  
  # Decrements the number of customers in service
  def decrement_customers
    update_attribute(:num_customers, num_customers - 1)
  end
end
