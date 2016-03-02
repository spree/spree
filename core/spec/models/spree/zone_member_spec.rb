require 'spec_helper'

describe Spree::ZoneMember, type: :model do
  let(:country) { create(:country) }
  let(:state) { create(:state) }
  let(:zone) { create(:zone, kind: 'country') }
  let(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }

  describe 'associations' do
    it { is_expected.to belong_to(:zoneable) }
    it { is_expected.to belong_to(:zone).counter_cache(true).inverse_of(:zone_members) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:zone) }
    it { is_expected.to validate_presence_of(:zoneable) }
  end

  describe 'scopes' do
    describe '.defunct_without_kind' do
      let(:defunct_without_kind) { Spree::ZoneMember.defunct_without_kind('country') }

      context 'zoneable is present and is of defunct kind' do
        it { expect(defunct_without_kind).to_not include(zone_member) }
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
