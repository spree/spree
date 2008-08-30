class Car < Vehicle
  state_machine :state do
    event :reverse do
      transition :to => 'backing_up', :from => %w(parked idling first_gear)
    end
    
    event :park do
      transition :to => 'parked', :from => 'backing_up'
    end
    
    event :idle do
      transition :to => 'idling', :from => 'backing_up'
    end
    
    event :shift_up do
      transition :to => 'first_gear', :from => 'backing_up'
    end
  end
end
