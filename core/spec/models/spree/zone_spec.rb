require 'spec_helper'

describe Spree::Zone, type: :model do
  let(:country) { create(:country) }
  let(:state) { create(:state, country: country) }
  let(:country_zone) { create(:zone, kind: 'country') }
  let(:state_zone) { create(:zone, kind: 'state') }

  context "#match" do
    before { country_zone.members.create(zoneable: country) }

    context "when there is only one qualifying zone" do
      let(:address) { create(:address, country: country, state: state) }

      it "should return the qualifying zone" do
        expect(Spree::Zone.match(address)).to eq(country_zone)
      end
    end

    context "when there are two qualified zones with same member type" do
      let(:address) { create(:address, country: country, state: state) }
      let(:second_zone) { create(:zone, name: 'SecondZone') }

      before { second_zone.members.create(zoneable: country) }

      context "when both zones have the same number of members" do
        it "should return the zone that was created first" do
          expect(Spree::Zone.match(address)).to eq(country_zone)
        end
      end

      context "when one of the zones has fewer members" do
        let(:country2) { create(:country) }

        before { country_zone.members.create(zoneable: country2) }

        it "should return the zone with fewer members" do
          expect(Spree::Zone.match(address)).to eq(second_zone)
        end
      end
    end

    context "when there are two qualified zones with different member types" do
      let(:address) { create(:address, country: country, state: state) }

      before { state_zone.members.create!(zoneable: state) }

      it "should return the zone with the more specific member type" do
        expect(Spree::Zone.match(address)).to eq(state_zone)
      end
    end

    context "when there are no qualifying zones" do
      it "should return nil" do
        expect(Spree::Zone.match(Spree::Address.new)).to be_nil
      end
    end
  end

  context "#country_list" do
    context "when zone consists of countries" do

      before { country_zone.members.create(zoneable: country) }

      it 'should return a list of countries' do
        expect(country_zone.country_list).to eq([country])
      end
    end

    context "when zone consists of states" do
      before { state_zone.members.create(zoneable: state) }

      it 'should return a list of countries' do
        expect(state_zone.country_list).to eq([state.country])
      end
    end
  end

  context "#include?" do
    let(:address) { create(:address, state: state) }

    context "when zone is country type" do
      before { country_zone.members.create(zoneable: country) }

      it "should be true" do
        expect(country_zone.include?(address)).to be true
      end
    end

    context "when zone is state type" do
      before { state_zone.members.create(zoneable: state) }

      it "should be true" do
        expect(state_zone.include?(address)).to be true
      end
    end
  end

  context ".default_tax" do
    context "when there is a default tax zone specified" do
      before { @foo_zone = create(:zone, name: 'whatever', default_tax: true) }

      it "should be the correct zone" do
        foo_zone = create(:zone, name: 'foo')
        expect(Spree::Zone.default_tax).to eq(@foo_zone)
      end
    end

    context "when there is no default tax zone specified" do
      it "should be nil" do
        expect(Spree::Zone.default_tax).to be_nil
      end
    end
  end

  context "#contains?" do
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

    context "when the target has no members" do
      before { @source.members.create(zoneable: country1) }

      it "should be false" do
        expect(@source.contains?(@target)).to be false
      end
    end

    context "when the source has no members" do
      before { @target.members.create(zoneable: country1) }

      it "should be false" do
        expect(@source.contains?(@target)).to be false
      end
    end

    context "when both zones are the same zone" do
      before do
        @source.members.create(zoneable: country1)
        @target = @source
      end

      it "should be true" do
        expect(@source.contains?(@target)).to be true
      end
    end

    context "when checking countries against countries" do
      before do
        @source.members.create(zoneable: country1)
        @source.members.create(zoneable: country2)
      end

      context "when all members are included in the zone we check against" do
        before do
          @target.members.create(zoneable: country1)
          @target.members.create(zoneable: country2)
        end

        it "should be true" do
          expect(@source.contains?(@target)).to be true
        end
      end

      context "when some members are included in the zone we check against" do
        before do
          @target.members.create(zoneable: country1)
          @target.members.create(zoneable: country2)
          @target.members.create(zoneable: create(:country))
        end

        it "should be false" do
          expect(@source.contains?(@target)).to be false
        end
      end

      context "when none of the members are included in the zone we check against" do
        before do
          @target.members.create(zoneable: create(:country))
          @target.members.create(zoneable: create(:country))
        end

        it "should be false" do
          expect(@source.contains?(@target)).to be false
        end
      end
    end


    context "when checking states against states" do
      before do
        @source.members.create(zoneable: state1)
        @source.members.create(zoneable: state2)
      end

      context "when all members are included in the zone we check against" do
        before do
          @target.members.create(zoneable: state1)
          @target.members.create(zoneable: state2)
        end

        it "should be true" do
          expect(@source.contains?(@target)).to be true
        end
      end

      context "when some members are included in the zone we check against" do
        before do
          @target.members.create(zoneable: state1)
          @target.members.create(zoneable: state2)
          @target.members.create(zoneable: create(:state))
        end

        it "should be false" do
          expect(@source.contains?(@target)).to be false
        end
      end

      context "when none of the members are included in the zone we check against" do
        before do
          @target.members.create(zoneable: create(:state))
          @target.members.create(zoneable: create(:state))
        end

        it "should be false" do
          expect(@source.contains?(@target)).to be false
        end
      end
    end

    context "when checking country against state" do
      before do
        @source.members.create(zoneable: create(:state))
        @target.members.create(zoneable: country1)
      end

      it "should be false" do
        expect(@source.contains?(@target)).to be false
      end
    end

    context "when checking state against country" do
      before { @source.members.create(zoneable: country1) }

      context "when all states contained in one of the countries we check against" do

        before do
          state1 = create(:state, country: country1)
          @target.members.create(zoneable: state1)
        end

        it "should be true" do
          expect(@source.contains?(@target)).to be true
        end
      end

      context "when some states contained in one of the countries we check against" do
        before do
          state1 = create(:state, country: country1)
          @target.members.create(zoneable: state1)
          @target.members.create(zoneable: create(:state, country: country2))
        end

        it "should be false" do
          expect(@source.contains?(@target)).to be false
        end
      end

      context "when none of the states contained in any of the countries we check against" do
        before do
          @target.members.create(zoneable: create(:state, country: country2))
          @target.members.create(zoneable: create(:state, country: country2))
        end

        it "should be false" do
          expect(@source.contains?(@target)).to be false
        end
      end
    end
  end

  context "#save" do
    context "when default_tax is true" do
      it "should clear previous default tax zone" do
        zone1 = create(:zone, name: 'foo', default_tax: true)
        zone = create(:zone, name: 'bar', default_tax: true)
        expect(zone1.reload.default_tax).to be false
      end
    end

    context "when a zone member country is added to an existing zone consisting of state members" do
      it "should remove existing state members" do
        zone = create(:zone, name: 'foo', zone_members: [])
        zone.members.create(zoneable: state)
        country_member = zone.members.create(zoneable: country)
        zone.save
        expect(zone.reload.members).to eq([country_member])
      end
    end
  end

  context "#kind" do
    it "returns whatever value you set" do
      zone = Spree::Zone.new kind: 'city'
      expect(zone.kind).to eq 'city'
    end

    context "when the zone consists of country zone members" do
      before do
        @zone = create(:zone, name: 'country', zone_members: [])
        @zone.members.create(zoneable: create(:country))
      end

      it "should return the kind of zone member" do
        expect(@zone.kind).to eq("country")
      end
    end
  end

  context "#potential_matching_zones" do
    let!(:country2) { create(:country, name: 'OtherCountry') }
    let!(:country3) { create(:country, name: 'TaxCountry') }
    let!(:default_tax_zone) do
      create(:zone, default_tax: true).tap { |z| z.members.create(zoneable: country3) }
    end

    context "finding potential matches for a country zone" do
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

      it "will find all zones with countries covered by the passed in zone" do
        expect(@result).to include(zone, zone2)
      end

      it "only returns each zone once" do
        expect(@result.select { |z| z == zone }.size).to be 1
      end
    end

    context "finding potential matches for a state zone" do
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

      it "will find all zones which share states covered by passed in zone" do
        expect(@result).to include(zone, zone2)
      end

      it "will find zones that share countries with any states of the passed in zone" do
        expect(@result).to include(zone3)
      end

      it "only returns each zone once" do
        expect(@result.select { |z| z == zone }.size).to be 1
      end
    end
  end

  context "state and country associations" do

    context "has countries associated" do
      let!(:zone) do
        create(:zone, countries: [country])
      end

      it "can access associated countries" do
        expect(zone.countries).to include(country)
      end
    end

    context "has states associated" do
      let!(:zone) do
        create(:zone, states: [state])
      end

      it "can access associated states" do
        expect(zone.states).to include(state)
      end
    end
  end

  describe '#state?' do
    it { expect(state_zone.state?).to be_truthy }
    it { expect(country_zone.state?).to be_falsy }
  end

  describe '#country?' do
    it { expect(state_zone.country?).to be_falsy }
    it { expect(country_zone.country?).to be_truthy }
  end

  describe '#country_ids' do
    let!(:zone) { create(:zone, countries: [country]) }
    it { expect(zone.country_ids).to eq([country.id]) }
    it { expect(zone.state_ids).to eq([]) }
  end

  describe '#state_ids' do
    let!(:zone) { create(:zone, states: [state]) }
    it { expect(zone.state_ids).to eq([state.id]) }
    it { expect(zone.country_ids).to eq([]) }
  end

  describe '#kind_of?' do
    it { expect(state_zone.send(:kind_alike?, 'state')).to be_truthy }
    it { expect(country_zone.send(:kind_alike?, 'state')).to be_falsy }
    it { expect(state_zone.send(:kind_alike?, 'country')).to be_falsy }
    it { expect(country_zone.send(:kind_alike?, 'country')).to be_truthy }
  end

  describe '#zoneable_ids' do
    context 'will have country_ids' do
      let!(:zone) { create(:zone, countries: [country]) }
      it { expect(zone.send(:zoneable_ids, 'country')).to eq([country.id]) }
      it { expect(zone.send(:zoneable_ids, 'state')).to eq([]) }
    end

    context 'will have state_ids' do
      let!(:zone) { create(:zone, states: [state]) }
      it { expect(zone.send(:zoneable_ids, 'state')).to eq([state.id]) }
      it { expect(zone.send(:zoneable_ids, 'country')).to eq([]) }
    end
  end
end
