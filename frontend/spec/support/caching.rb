RSpec.configure do |config|
  config.around(:each, :caching) do |example|
    caching = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = example.metadata[:caching]

    example.run

    Rails.cache.clear
    ActionController::Base.perform_caching = caching
  end
end
