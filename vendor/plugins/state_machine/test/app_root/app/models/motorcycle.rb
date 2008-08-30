class Motorcycle < Vehicle
  state_machine :state, :initial => 'idling'
end
