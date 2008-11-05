class GatewayConfig < Configuration

  preference :use_bogus, :boolean, :default => true # use the bogus gateway in development mode
  
  validates_presence_of :name
  validates_uniqueness_of :name
end