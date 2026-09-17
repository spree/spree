require 'spec_helper'

RSpec.describe Spree::AgentTools::RecordSummary do
  # Every record the assistant emits crosses the wire to a third-party AI vendor
  # and is stored in chat history, so this filter is the last thing standing
  # between a serializer that gains a credential field and a live secret leaving
  # the building.
  describe '.sanitize' do
    it 'drops credential-shaped keys' do
      result = described_class.sanitize(
        'name' => 'Keep me',
        'api_key' => 'sk-live-LEAK',
        'webhook_secret' => 'whsec_LEAK',
        'access_token' => 'LEAK',
        'password_digest' => 'LEAK'
      )

      expect(result.keys).to contain_exactly('name')
    end

    it 'reaches inside nested associations' do
      # Serializers nest — an order carries a market, a customer carries
      # addresses. A shallow filter scrubbed the top level and forwarded
      # whatever sat one layer down.
      result = described_class.sanitize(
        'number' => 'R1001',
        'market' => { 'name' => 'EU', 'api_key' => 'sk-live-LEAK' },
        'payments' => [{ 'amount' => '10', 'token' => 'LEAK' }]
      )

      expect(result.to_s).not_to include('LEAK')
      expect(result['market']['name']).to eq('EU')
      expect(result['payments'].first['amount']).to eq('10')
    end

    it 'drops a gift card wholesale, because its code is the bearer instrument' do
      result = described_class.sanitize('number' => 'R1', 'gift_card' => { 'code' => 'GC-SPENDABLE' })

      expect(result).not_to have_key('gift_card')
      expect(result['number']).to eq('R1')
    end

    it 'keeps a code that is an identifier rather than a secret' do
      # Channels, promotions and commission rates all use `code` as a name a
      # merchant asks about; blanket-stripping it would break real answers.
      result = described_class.sanitize('code' => 'freeship', 'name' => 'Free shipping')

      expect(result['code']).to eq('freeship')
    end
  end

  # A credential does not always sit under a credential-shaped key: several
  # serializers expose a link whose path or query string IS the secret, and the
  # endpoint it addresses authenticates on the link alone. Matching the key
  # name cannot catch those.
  describe 'a credential carried in a value' do
    it 'drops an invitation acceptance link' do
      cleaned = described_class.sanitize(
        'id' => 'inv_1', 'email' => 'hire@example.com',
        'acceptance_url' => '/accept-invitation/inv_1?token=LIVEtoken123'
      )

      expect(cleaned.to_s).not_to include('LIVEtoken123')
      expect(cleaned['email']).to eq('hire@example.com')
    end

    it 'drops a digital link download URL' do
      cleaned = described_class.sanitize('download_url' => '/api/v3/store/digital_links/LIVEtoken123')

      expect(cleaned.to_s).not_to include('LIVEtoken123')
    end

    it 'drops any link that authenticates on a query parameter' do
      cleaned = described_class.sanitize('report' => '/exports/5/download?token=LIVEtoken123')

      expect(cleaned.to_s).not_to include('LIVEtoken123')
    end

    it 'drops one nested inside an association' do
      cleaned = described_class.sanitize(
        'line_items' => [{ 'name' => 'Album', 'download_url' => '/api/v3/store/digital_links/LIVEtoken123' }]
      )

      expect(cleaned.to_s).not_to include('LIVEtoken123')
      expect(cleaned.dig('line_items', 0, 'name')).to eq('Album')
    end

    # Tags are caller-controlled and serialize as a bare string array, so an
    # element has to be filtered like a value, not just recursed into.
    it 'drops a credential carried in an array element' do
      cleaned = described_class.sanitize(
        'tags' => ['seasonal', 'https://example.test/?token=LIVEtoken123']
      )

      expect(cleaned.to_s).not_to include('LIVEtoken123')
      expect(cleaned['tags']).to eq(['seasonal'])
    end

    it 'drops one nested in an array of hashes' do
      cleaned = described_class.sanitize(
        'items' => [{ 'name' => 'Album', 'links' => ['/api/v3/store/digital_links/LIVEtoken123'] }]
      )

      expect(cleaned.to_s).not_to include('LIVEtoken123')
      expect(cleaned.dig('items', 0, 'name')).to eq('Album')
    end

    # The filter has to stay narrow: a merchant asks about storefront links,
    # and dropping every `*_url` would take those with it.
    it 'keeps an ordinary URL' do
      cleaned = described_class.sanitize(
        'name' => 'Blue Shirt',
        'url' => 'https://shop.example.com/products/blue-shirt',
        'thumbnail_url' => 'https://cdn.example.com/blue.jpg'
      )

      expect(cleaned['url']).to eq('https://shop.example.com/products/blue-shirt')
      expect(cleaned['thumbnail_url']).to eq('https://cdn.example.com/blue.jpg')
      expect(cleaned['name']).to eq('Blue Shirt')
    end
  end
end
