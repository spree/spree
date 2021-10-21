RSpec.configure do |config|
  config.before(:each, :spree_webhooks) do
    ENV['DISABLE_SPREE_WEBHOOKS'] = nil
  end

  config.after(:each, :spree_webhooks) do
    ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
  end
end
