require 'spec_helper'

RSpec.describe Spree::Actor do
  describe '#actor_label' do
    it 'names a person by their full name' do
      user = build(:admin_user, first_name: 'Ada', last_name: 'Lovelace')

      expect(user.actor_label).to eq('Ada Lovelace')
    end

    it 'falls back to the email when a person has no name' do
      user = build(:admin_user, first_name: nil, last_name: nil, email: 'ada@example.com')

      expect(user.actor_label).to eq('ada@example.com')
    end

    it 'names an API key by its name' do
      key = build(:api_key, name: 'WMS connector')

      expect(key.actor_label).to eq('WMS connector')
    end
  end

  describe '#actor_kind' do
    it 'answers the wire shorthand, not the class name' do
      expect(build(:admin_user).actor_kind).to eq('admin_user')
      expect(build(:api_key).actor_kind).to eq('api_key')
    end
  end

  describe 'Spree.actor_classes' do
    it 'registers the two kinds 6.0 ships with' do
      expect(Spree.actor_classes).to contain_exactly(Spree.admin_user_class.to_s, 'Spree::ApiKey')
    end
  end
end
