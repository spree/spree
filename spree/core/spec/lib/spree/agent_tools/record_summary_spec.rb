require 'spec_helper'

RSpec.describe Spree::Assistant::RecordSummary do
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
end
