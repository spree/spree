module SpreeSite
  class Engine < Rails::Engine
    def self.activate
      # Add your custom site logic here
    end
    config.to_prepare &method(:activate).to_proc
  end
end