# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::AllowedOrigin, type: :model do
  let(:store) { create(:store) }

  describe 'associations' do
    it { is_expected.to belong_to(:store).class_name('Spree::Store').without_validating_presence }
  end

  describe 'validations' do
    subject { build(:allowed_origin, store: store) }

    it { is_expected.to validate_presence_of(:origin) }

    it 'validates uniqueness of origin scoped to store' do
      create(:allowed_origin, store: store, origin: 'https://example.com')
      duplicate = build(:allowed_origin, store: store, origin: 'https://example.com')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:origin]).to include('has already been taken')
    end

    it 'allows same origin for different stores' do
      other_store = create(:store, code: 'other')
      create(:allowed_origin, store: store, origin: 'https://example.com')
      other = build(:allowed_origin, store: other_store, origin: 'https://example.com')
      expect(other).to be_valid
    end
  end

  describe 'origin format validation' do
    it 'accepts valid HTTPS origin' do
      origin = build(:allowed_origin, store: store, origin: 'https://myshop.com')
      expect(origin).to be_valid
    end

    it 'accepts valid HTTP origin' do
      origin = build(:allowed_origin, store: store, origin: 'http://localhost')
      expect(origin).to be_valid
    end

    it 'accepts origin with port' do
      origin = build(:allowed_origin, store: store, origin: 'http://localhost:3000')
      expect(origin).to be_valid
    end

    it 'accepts origin with trailing slash' do
      origin = build(:allowed_origin, store: store, origin: 'https://myshop.com/')
      expect(origin).to be_valid
    end

    it 'rejects origin with path' do
      origin = build(:allowed_origin, store: store, origin: 'https://myshop.com/reset-password')
      expect(origin).not_to be_valid
      expect(origin.errors[:origin]).to include('must be an origin (scheme and host) without path, query, or fragment')
    end

    it 'rejects origin with query string' do
      origin = build(:allowed_origin, store: store, origin: 'https://myshop.com?foo=bar')
      expect(origin).not_to be_valid
      expect(origin.errors[:origin]).to include('must be an origin (scheme and host) without path, query, or fragment')
    end

    it 'rejects origin with fragment' do
      origin = build(:allowed_origin, store: store, origin: 'https://myshop.com#section')
      expect(origin).not_to be_valid
      expect(origin.errors[:origin]).to include('must be an origin (scheme and host) without path, query, or fragment')
    end

    it 'rejects non-HTTP scheme' do
      origin = build(:allowed_origin, store: store, origin: 'ftp://myshop.com')
      expect(origin).not_to be_valid
      expect(origin.errors[:origin]).to include('is invalid')
    end

    it 'rejects invalid URI' do
      origin = build(:allowed_origin, store: store, origin: 'not a url at all')
      expect(origin).not_to be_valid
    end
  end

  describe '.normalize_origin' do
    it 'normalizes bare hosts to https origins' do
      expect(described_class.normalize_origin('MyShop.example.com/checkout?x=1')).to eq('https://myshop.example.com')
    end

    it 'strips only the scheme default port' do
      expect(described_class.normalize_origin('https://shop.example.com:443')).to eq('https://shop.example.com')
      expect(described_class.normalize_origin('http://shop.example.com:80')).to eq('http://shop.example.com')
      expect(described_class.normalize_origin('https://shop.example.com:80')).to eq('https://shop.example.com:80')
      expect(described_class.normalize_origin('http://shop.example.com:443')).to eq('http://shop.example.com:443')
    end

    it 'returns nil for unparseable input' do
      expect(described_class.normalize_origin('not a url')).to be_nil
      expect(described_class.normalize_origin('')).to be_nil
    end
  end

  describe '#loopback?' do
    it 'is true for loopback hosts regardless of port' do
      expect(build(:allowed_origin, store: store, origin: 'http://localhost').loopback?).to be true
      expect(build(:allowed_origin, store: store, origin: 'http://127.0.0.1:3000').loopback?).to be true
    end

    it 'is false for public hosts' do
      expect(build(:allowed_origin, store: store, origin: 'https://myshop.com').loopback?).to be false
    end
  end

  describe '#matches?' do
    subject(:allowed_origin) { build(:allowed_origin, store: store, origin: stored) }

    let(:stored) { 'https://myshop.com' }

    it 'matches the exact origin regardless of path' do
      expect(allowed_origin.matches?('https://myshop.com/reset-password')).to be true
    end

    it 'matches a non-loopback origin when the implicit default port is requested explicitly' do
      expect(allowed_origin.matches?('https://myshop.com:443/checkout')).to be true
    end

    it 'does not match a non-loopback origin on a non-standard port' do
      expect(allowed_origin.matches?('https://myshop.com:8080/checkout')).to be false
    end

    it 'does not match a different scheme' do
      expect(allowed_origin.matches?('http://myshop.com/page')).to be false
    end

    it 'does not match a different host' do
      expect(allowed_origin.matches?('https://evil.com/page')).to be false
    end

    it 'does not match a subdomain of the host' do
      expect(allowed_origin.matches?('https://app.myshop.com/page')).to be false
    end

    it 'matches regardless of host casing' do
      expect(allowed_origin.matches?('https://MyShop.com/page')).to be true
    end

    it 'ignores a trailing dot on the host' do
      expect(allowed_origin.matches?('https://myshop.com./page')).to be true
    end

    it 'does not treat userinfo as the host' do
      expect(allowed_origin.matches?('https://myshop.com@evil.com/page')).to be false
    end

    it 'returns false for non-http(s) and blank candidates' do
      expect(allowed_origin.matches?('ftp://myshop.com')).to be false
      expect(allowed_origin.matches?('javascript:alert(1)')).to be false
      expect(allowed_origin.matches?(nil)).to be false
    end

    context 'when the stored origin is a loopback host' do
      let(:stored) { 'http://localhost' }

      it 'matches any port' do
        expect(allowed_origin.matches?('http://localhost:3000/reset-password')).to be true
        expect(allowed_origin.matches?('http://localhost:5173')).to be true
      end
    end

    context 'when the stored origin pins an explicit non-standard port' do
      let(:stored) { 'https://staging.myshop.com:8443' }

      it 'matches only that port' do
        expect(allowed_origin.matches?('https://staging.myshop.com:8443/page')).to be true
        expect(allowed_origin.matches?('https://staging.myshop.com/page')).to be false
        expect(allowed_origin.matches?('https://staging.myshop.com:9000/page')).to be false
      end
    end
  end

  describe 'SingleStoreResource' do
    it 'prevents changing store after creation' do
      origin = create(:allowed_origin, store: store)
      other_store = create(:store, code: 'other2')
      origin.store = other_store
      expect(origin).not_to be_valid
    end
  end

  describe 'prefix_id' do
    it 'generates ao_ prefixed id' do
      origin = create(:allowed_origin, store: store)
      expect(origin.prefixed_id).to start_with('ao_')
    end
  end
end
