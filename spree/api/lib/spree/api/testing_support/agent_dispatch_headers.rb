# A tool that dispatches to the Admin API authenticates as the caller did, so
# a spec building a context by hand has to supply the credential a real
# request would have carried. Minting one belongs here, in test support —
# never in the dispatcher, which forwards and nothing else.
module AgentDispatchHeaders
  # @param user [Object] a Spree admin user
  # @return [Hash] Rack headers carrying that user's admin JWT
  def agent_headers_for(user)
    token = Spree::Api::V3::TestingSupport.generate_jwt(
      user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
    )

    { 'HTTP_AUTHORIZATION' => "Bearer #{token}", 'HTTP_HOST' => 'www.example.com' }
  end

  # @param api_key [Spree::ApiKey] a secret key, still holding its plaintext
  # @return [Hash] Rack headers carrying that key
  def agent_headers_for_key(api_key)
    { 'HTTP_X_SPREE_API_KEY' => api_key.plaintext_token, 'HTTP_HOST' => 'www.example.com' }
  end
end

RSpec.configure { |config| config.include AgentDispatchHeaders }
