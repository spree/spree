module Spree
  class ApiConfiguration < Preferences::Configuration
    preference :requires_authentication, :boolean, default: true
    preference :api_v2_content_type, :string, default: 'application/vnd.api+json'
    preference :api_v2_per_page_limit, :integer, default: 100
  end
end
