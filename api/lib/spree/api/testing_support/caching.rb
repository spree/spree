RSpec.configure do |config|
  config.before(:each, :caching => true) do 
    ActionController::Base.perform_caching = true
  end
  
  config.after(:each, :caching => true) do
    ActionController::Base.perform_caching = false
    Rails.cache.clear
  end
end