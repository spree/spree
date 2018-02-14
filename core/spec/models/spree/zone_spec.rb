require 'spec_helper'

describe Spree::Zone, type: :model do
  context '#match' do
    let(:country_zone) { create(:zone, kind: 'country') }

    let(:country) do
      create(:country)
    end

    let(:state) do
      create(:state, country: country)
    end

    before { country_zone.members.create(zoneable: country) }

    describe 'scopes' do
      describe '.remove_previous_default' do
        subject { Spree::Zone.with_default_tax }

        let(:zone_with_default_tax) { create(:zone, kind: 'country', default_tax: true) }
        let(:zone_not_with_default_tax) { create(:zone, kind: 'country', default_tax: false) }

        it 'is expected to include zone with default tax' do
          is_expected.to include(zone_with_default_tax)
        end

        it 'is expected to not include zone with default tax' do
          is_expected.not_to include(zone_not_with_default_tax)
        end
      end
    end

    describe 'callbacks' do
      describe '#remove_previous_default' do
        let!(:zone_with_default_tax) { create(:zone, kind: 'country', default_tax: true) }
        let!(:zone_not_with_default_tax) { create(:zone, kind: 'country', default_tax: false) }

        it 'is expected to make previous default tax zones to non default tax zones' do
          expect(zone_with_default_tax).to be_default_tax
          zone_not_with_default_tax.update(default_tax: true)
          expect(zone_with_default_tax.reload).not_to be_default_tax
        end
      end
    end

    context 'when there is only one qualifying zone' do
      let(:address) { create(:address, country: country, state: state) }

      it 'returns the qualifying zone' do
        expect(Spree::Zone.match(address)).to eq(country_zone)
      end
    end

    context 'when there are two qualified zones with same member type' do
      let(:address) { create(:address, country: country, state: state) }
      let(:second_zone) { create(:zone, name: 'SecondZone') }

      before { second_zone.members.create(zoneable: country) }

      context 'when both zones have the same number of members' do
        it 'returns the zone that was created first' do
          Timecop.scale(100) do
            expect(Spree::Zone.match(address)).to eq(country_zone)
          end
        end
      end

      context 'when one of the zones has fewer members' do
        let(:country2) { create(:country) }

        before { country_zone.members.create(zoneable: country2) }

        it 'returns the zone with fewer members' do
          expect(Spree::Zone.match(address)).to eq(second_zone)
        end
      end
    end

    context 'when there are two qualified zones with different member types' do
      let(:state_zone) { create(:zone, kind: 'state') }
      let(:address) { create(:address, country: country, state: state) }

      before { state_zone.members.create!(zoneable: state) }

      it 'returns the zone with the more specific member type' do
        expect(Spree::Zone.match(address)).to eq(state_zone)
      end
    end

    context 'when there are no qualifying zones' do
      it 'returns nil' do
        expect(Spree::Zone.match(Spree::Address.new)).to be_nil
      end
    end
  end

  context '#country_list' do
    let(:state) { create(:state) }
    let(:country) { state.country }

    context 'when zone consists of countries' do
      let(:country_zone) { create(:zone, kind: 'country') }

      before { country_zone.members.create(zoneable: country) }

      it 'returns a list of countries' do
        expect(country_zone.country_list).to eq([country])
      end
    end

    context 'when zone consists of states' do
      let(:state_zone) { create(:zone, kind: 'state') }

      before { state_zone.members.create(zoneable: state) }

      it 'returns a list of countries' do
        expect(state_zone.country_list).to eq([state.country])
      end
    end
  end

  context '#include?' do
    let(:state) { create(:state) }
    let(:country) { state.country }
    let(:address) { create(:address, state: state) }

    context 'when zone is country type' do
      let(:country_zone) { create(:zone, kind: 'country') }

      before { country_zone.members.create(zoneable: country) }

      it 'is true' do
        expect(country_zone.include?(address)).to be true
      end
    end

    context 'when zone is state type' do
      let(:state_zone) { create(:zone, kind: 'state') }

      before { state_zone.members.create(zoneable: state) }

      it 'is true' do
        expect(state_zone.include?(address)).to be true
      end
    end
  end

  context '.default_tax' do
    context 'when there is a default tax zone specified' do
      before { @foo_zone = create(:zone, name: 'whatever', default_tax: true) }

      it 'is the correct zone' do
        create(:zone, name: 'foo')
        expect(Spree::Zone.default_tax).to eq(@foo_zone)
      end
    end

    context 'when there is no default tax zone specified' do
      it 'is nil' do
        expect(Spree::Zone.default_tax).to be_nil
      end
    end
  end

  context '#contains?' do
    let(:country1) { create(:country) }
    let(:country2) { create(:country) }
    let(:country3) { create(:country) }

    let(:state1) { create(:state) }
    let(:state2) { create(:state) }
    let(:state3) { create(:state) }

    before do
      @source = create(:zone, name: 'source', zone_members: [])
      @target = create(:zone, name: 'target', zone_members: [])
    end

    context 'when the target has no members' do
      before { @source.members.create(zoneable: country1) }

      it 'is false' do
        expect(@source.contains?(@target)).to be false
      end
    end

    context 'when the source has no members' do
      before { @target.members.create(zoneable: country1) }

      it 'is false' do
        expect(@source.contains?(@target)).to be false
      end
    end

    context 'when both zones are the same zone' do
      before do
        @source.members.create(zoneable: country1)
        @target = @source
      end

      it 'is true' do
        expect(@source.contains?(@target)).to be true
      end
    end

    context 'when checking countries against countries' do
      before do
        @source.members.create(zoneable: country1)
        @source.members.create(zoneable: country2)
      end

      context 'when all members are included in the zone we check against' do
        before do
          @target.members.create(zoneable: country1)
          @target.members.create(zoneable: country2)
        end

        it 'is true' do
          expect(@source.contains?(@target)).to be true
        end
      end

      context 'when some members are included in the zone we check against' do
        before do
          @target.members.create(zoneable: country1)
          @target.members.create(zoneable: country2)
          @target.members.create(zoneable: create(:country))
        end

        it 'is false' do
          expect(@source.contains?(@target)).to be false
        end
      end

      context 'when none of the members are included in the zone we check against' do
        before do
          @target.members.create(zoneable: create(:country))
          @target.members.create(zoneable: create(:country))
        end

        it 'is false' do
          expect(@source.contains?(@target)).to be false
        end
      end
    end

    context 'when checking states against states' do
      before do
        @source.members.create(zoneable: state1)
        @source.members.create(zoneable: state2)
      end

      context 'when all members are included in the zone we check against' do
        before do
          @target.members.create(zoneable: state1)
          @target.members.create(zoneable: state2)
        end

        it 'is true' do
          expect(@source.contains?(@target)).to be true
        end
      end

      context 'when some members are included in the zone we check against' do
        before do
          @target.members.create(zoneable: state1)
          @target.members.create(zoneable: state2)
          @target.members.create(zoneable: create(:state))
        end

        it 'is false' do
          expect(@source.contains?(@target)).to be false
        end
      end

      context 'when none of the members are included in the zone we check against' do
        before do
          @target.members.create(zoneable: create(:state))
          @target.members.create(zoneable: create(:state))
        end

        it 'is false' do
          expect(@source.contains?(@target)).to be false
        end
      end
    end

    context 'when checking country against state' do
      before do
        @source.members.create(zoneable: create(:state))
        @target.members.create(zoneable: country1)
      end

      it 'is false' do
        expect(@source.contains?(@target)).to be false
      end
    end

    context 'when checking state against country' do
      before { @source.members.create(zoneable: country1) }

      context 'when all states contained in one of the countries we check against' do
        before do
          state1 = create(:state, country: country1)
          @target.members.create(zoneable: state1)
        end

        it 'is true' do
          expect(@source.contains?(@target)).to be true
        end
      end

      context 'when some states contained in one of the countries we check against' do
        before do
          state1 = create(:state, country: country1)
          @target.members.create(zoneable: state1)
          @target.members.create(zoneable: create(:state, country: country2))
        end

        it 'is false' do
          expect(@source.contains?(@target)).to be false
        end
      end

      context 'when none of the states contained in any of the countries we check against' do
        before do
          @target.members.create(zoneable: create(:state, country: country2))
          @target.members.create(zoneable: create(:state, country: country2))
        end

        it 'is false' do
          expect(@source.contains?(@target)).to be false
        end
      end
    end
  end

  context '#save' do
    context 'when default_tax is true' do
      it 'clears previous default tax zone' do
        zone1 = create(:zone, name: 'foo', default_tax: true)
        create(:zone, name: 'bar', default_tax: true)
        expect(zone1.reload.default_tax).to be false
      end
    end

    context 'when a zone member country is added to an existing zone consisting of state members' do
      it 'removes existing state members' do
        zone = create(:zone, name: 'foo', zone_members: [])
        state = create(:state)
        country = create(:country)
        zone.members.create(zoneable: state)
        country_member = zone.members.create(zoneable: country)
        zone.save
        expect(zone.reload.members).to eq([country_member])
      end
    end
  end

  context '#kind' do
    it 'returns whatever value you set' do
      zone = Spree::Zone.new kind: 'city'
      expect(zone.kind).to eq 'city'
    end

    context 'when the zone consists of country zone members' do
      before do
        @zone = create(:zone, name: 'country', zone_members: [])
        @zone.members.create(zoneable: create(:country))
      end

      it 'returns the kind of zone member' do
        expect(@zone.kind).to eq('country')
      end
    end
  end

  context '#potential_matching_zones' do
    let!(:country)  { create(:country) }
    let!(:country2) { create(:country, name: 'OtherCountry') }
    let!(:country3) { create(:country, name: 'TaxCountry') }
    let!(:default_tax_zone) do
      create(:zone, default_tax: true).tap { |z| z.members.create(zoneable: country3) }
    end

    context 'finding potential matches for a country zone' do
      let!(:zone) do
        create(:zone).tap do |z|
          z.members.create(zoneable: country)
          z.members.create(zoneable: country2)
          z.save!
        end
      end
      let!(:zone2) do
        create(:zone).tap { |z| z.members.create(zoneable: country) && z.save! }
      end

      before { @result = Spree::Zone.potential_matching_zones(zone) }

      it 'will find all zones with countries covered by the passed in zone' do
        expect(@result).to include(zone, zone2)
      end

      it 'only returns each zone once' do
        expect(@result.select { |z| z == zone }.size).to be 1
      end
    end

    context 'finding potential matches for a state zone' do
      let!(:state)  { create(:state, country: country) }
      let!(:state2) { create(:state, country: country2, name: 'OtherState') }
      let!(:state3) { create(:state, country: country2, name: 'State') }
      let!(:zone) do
        create(:zone).tap do |z|
          z.members.create(zoneable: state)
          z.members.create(zoneable: state2)
          z.save!
        end
      end
      let!(:zone2) do
        create(:zone).tap { |z| z.members.create(zoneable: state) && z.save! }
      end
      let!(:zone3) do
        create(:zone).tap { |z| z.members.create(zoneable: state2) && z.save! }
      end

      before { @result = Spree::Zone.potential_matching_zones(zone) }

      it 'will find all zones which share states covered by passed in zone' do
        expect(@result).to include(zone, zone2)
      end

      it 'will find zones that share countries with any states of the passed in zone' do
        expect(@result).to include(zone3)
      end

      it 'only returns each zone once' do
        expect(@result.select { |z| z == zone }.size).to be 1
      end
    end
  end

  context 'state and country associations' do
    let!(:country) { create(:country) }

    context 'has countries associated' do
      let!(:zone) do
        create(:zone, countries: [country])
      end

      it 'can access associated countries' do
        expect(zone.countries).to include(country)
      end
    end

    context 'has states associated' do
      let!(:state) { create(:state, country: country) }
      let!(:zone) do
        create(:zone, states: [state])
      end

      it 'can access associated states' do
        expect(zone.states).to include(state)
      end
    end
  end
end
