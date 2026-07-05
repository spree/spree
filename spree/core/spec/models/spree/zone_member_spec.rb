require 'spec_helper'

describe Spree::ZoneMember, type: :model do
  let(:country) { create(:country) }
  let(:state) { create(:state) }
  let(:zone) { create(:zone, kind: 'country') }
  let(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }

  describe 'validations' do
    it 'does not allow duplicate zoneable in the same zone' do
      zone_member
      duplicate = build(:zone_member, zone: zone, zoneable: country)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:zoneable_id]).to be_present
    end

    it 'allows the same zoneable in different zones' do
      zone_member
      other_zone = create(:zone, kind: 'country')
      other_member = build(:zone_member, zone: other_zone, zoneable: country)
      expect(other_member).to be_valid
    end
  end

  describe 'scopes' do
    describe '.defunct_without_kind' do
      let(:defunct_without_kind) { Spree::ZoneMember.defunct_without_kind('country') }

      context 'zoneable is present and is of defunct kind' do
        it { expect(defunct_without_kind).not_to include(zone_member) }
      end

      context 'zoneable is not of defunct kind' do
        before { zone_member.update(zoneable: state) }

        it { expect(defunct_without_kind).to include(zone_member) }
      end

      context 'zoneable is absent' do
        before { zone_member.update_column(:zoneable_id, nil) }

        it { expect(defunct_without_kind).to include(zone_member) }
      end
    end
  end
end
