require 'spec_helper'

describe Spree::DeliveryZoneMember, type: :model do
  let(:zone) { create(:delivery_zone) }
  let(:germany) { create(:country, iso: 'DE', iso3: 'DEU', name: 'Germany', iso_name: 'GERMANY') }
  let(:uk) { create(:country, iso: 'GB', iso3: 'GBR', name: 'United Kingdom', iso_name: 'UNITED KINGDOM') }

  describe '#match?' do
    context 'country member' do
      let(:member) { create(:delivery_zone_member, delivery_zone: zone, member_type: 'country', country: germany) }

      it 'matches addresses in the country and rejects others' do
        expect(member.match?(build(:address, country: germany))).to be(true)
        expect(member.match?(build(:address, country: uk))).to be(false)
      end
    end

    context 'state member' do
      let(:state) { create(:state, country: germany) }
      let(:member) { create(:delivery_zone_member, delivery_zone: zone, member_type: 'state', country: nil, state: state) }

      it 'matches addresses in the state and rejects others' do
        expect(member.match?(build(:address, country: germany, state: state))).to be(true)
        expect(member.match?(build(:address, country: germany, state: create(:state, country: germany)))).to be(false)
      end
    end

    context 'postal prefix member' do
      let(:member) do
        create(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                      country: uk, postal_code_prefix: 'sw1')
      end

      it 'matches normalized zipcodes by prefix, scoped to the country' do
        expect(member.match?(build(:address, country: uk, zipcode: 'SW1A 1AA'))).to be(true)
        expect(member.match?(build(:address, country: uk, zipcode: 'EC1A 1BB'))).to be(false)
        expect(member.match?(build(:address, country: germany, zipcode: 'SW1A 1AA'))).to be(false)
      end
    end

    context 'postal range member' do
      let(:member) do
        create(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                      country: germany, postal_code_from: '10115', postal_code_to: '10999')
      end

      it 'matches zipcodes inside the range, scoped to the country' do
        expect(member.match?(build(:address, country: germany, zipcode: '10 405'))).to be(true)
        expect(member.match?(build(:address, country: germany, zipcode: '11011'))).to be(false)
        expect(member.match?(build(:address, country: germany, zipcode: ''))).to be(false)
      end
    end
  end

  describe 'postal member validation' do
    it 'normalizes prefix and range bounds on save' do
      member = create(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                             country: uk, postal_code_prefix: ' sw1-a ')

      expect(member.postal_code_prefix).to eq('SW1A')
    end

    it 'rejects a prefix combined with a range' do
      member = build(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                            country: germany, postal_code_prefix: '10', postal_code_from: '10115', postal_code_to: '10999')

      expect(member).not_to be_valid
      expect(member.errors[:postal_code_prefix]).to be_present
    end

    it 'requires a prefix or a complete range' do
      member = build(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                            country: germany, postal_code_from: '10115')

      expect(member).not_to be_valid
      expect(member.errors[:base]).to be_present
    end

    it 'rejects ranges for countries outside the numeric-postal allowlist' do
      member = build(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                            country: uk, postal_code_from: '10115', postal_code_to: '10999')

      expect(member).not_to be_valid
      expect(member.errors[:base]).to be_present
    end

    it 'allows prefixes for any country' do
      member = build(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                            country: uk, postal_code_prefix: 'SW1')

      expect(member).to be_valid
    end

    it 'rejects an inverted range' do
      member = build(:delivery_zone_member, delivery_zone: zone, member_type: 'postal_code',
                                            country: germany, postal_code_from: '10999', postal_code_to: '10115')

      expect(member).not_to be_valid
      expect(member.errors[:postal_code_to]).to be_present
    end
  end
end
