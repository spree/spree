RSpec.configure do |config|
  config.before(:each, :spree_webhooks) do
    Spree::Webhooks.disabled = false
  end

  config.after(:each, :spree_webhooks) do
    Spree::Webhooks.disabled = true
  end
end
