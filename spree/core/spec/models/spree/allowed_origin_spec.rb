# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::AllowedOrigin, type: :model do
  let(:store) { create(:store) }

  describe 'associations' do
    it { is_expected.to belong_to(:store).class_name('Spree::Store').without_validating_presence }
  end

  describe 'validations' do
    subject { build(:allowed_origin, store: store) }

    it { is_expected.to validate_presence_of(:store) }
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
