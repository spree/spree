shared_context 'API v2 tokens' do
  let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: nil) }
  let(:headers_bearer) { { 'Authorization' => "Bearer #{token.token}" } }
  let(:headers_order_token) { { 'X-Spree-Order-Token' => order.token } }
end

[200, 201, 204, 400, 401, 404, 403, 422].each do |status_code|
  shared_examples "returns #{status_code} HTTP status" do
    it "returns #{status_code}" do
      expect(response.status).to eq(status_code)
    end
  end
end
