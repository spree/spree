class Vehicle < ActiveRecord::Base
  belongs_to :auto_shop
  belongs_to :highway
  
  attr_accessor :force_idle
  attr_accessor :callbacks
  
  # Defines the state machine for the state of the vehicle
  state_machine :state, :initial => Proc.new {|vehicle| vehicle.force_idle ? 'idling' : 'parked'} do
    before_exit   'parked', :put_on_seatbelt
    after_enter   'parked', Proc.new {|vehicle| vehicle.update_attribute(:seatbelt_on, false)}
    before_enter  'stalled', :increase_insurance_premium
    
    # Callback tracking for initial state callbacks
    after_enter   'parked', Proc.new {|vehicle| (vehicle.callbacks ||= []) << 'before_enter_parked'}
    before_enter  'idling', Proc.new {|vehicle| (vehicle.callbacks ||= []) << 'before_enter_idling'}
    
    event :park do
      transition :to => 'parked', :from => %w(idling first_gear)
    end
    
    event :ignite do
      transition :to => 'stalled', :from => 'stalled'
      transition :to => 'idling', :from => 'parked'
    end
    
    event :idle do
      transition :to => 'idling', :from => 'first_gear'
    end
    
    event :shift_up do
      transition :to => 'first_gear', :from => 'idling'
      transition :to => 'second_gear', :from => 'first_gear'
      transition :to => 'third_gear', :from => 'second_gear'
    end
    
    event :shift_down do
      transition :to => 'second_gear', :from => 'third_gear'
      transition :to => 'first_gear', :from => 'second_gear'
    end
    
    event :crash, :after => :tow! do
      transition :to => 'stalled', :from => %w(first_gear second_gear third_gear), :if => Proc.new {|vehicle| vehicle.auto_shop.available?}
    end
    
    event :repair, :after => :fix! do
      transition :to => 'parked', :from => 'stalled', :if => :auto_shop_busy?
    end
  end
  
  # Tows the vehicle to the auto shop
  def tow!
    auto_shop.tow_vehicle!
  end
  
  # Fixes the vehicle; it will no longer be in the auto shop
  def fix!
    auto_shop.fix_vehicle!
  end
  
  private
    # Safety first! Puts on our seatbelt
    def put_on_seatbelt
      self.seatbelt_on = true
    end
    
    # We crashed! Increase the insurance premium on the vehicle
    def increase_insurance_premium
      update_attribute(:insurance_premium, self.insurance_premium + 100)
    end
    
    # Is the auto shop currently servicing another customer?
    def auto_shop_busy?
      auto_shop.busy?
    end
end
