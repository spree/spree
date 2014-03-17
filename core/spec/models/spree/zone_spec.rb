require 'spec_helper'

describe Spree::Zone do
  context "#match" do
    let(:country_zone) { create(:zone, name: 'CountryZone') }

    before { country_zone.members.create(country_code: 'US') }

    context "when there is only one qualifying zone" do
      let(:address) { create(:address, country_code: 'US', region_code: 'CT') }

      it "should return the qualifying zone" do
        Spree::Zone.match(address).should == country_zone
      end
    end

    context "when there are two qualified zones with same member type" do
      let(:address) { create(:address, country_code: 'US', region_code: 'CT') }
      let(:second_zone) { create(:zone, name: 'SecondZone') }

      before { second_zone.members.create(country_code: 'US') }

      context "when both zones have the same number of members" do
        it "should return the zone that was created first" do
          Spree::Zone.match(address).should == country_zone
        end
      end

      context "when one of the zones has fewer members" do
        before { country_zone.members.create(country_code: 'CA') }

        it "should return the zone with fewer members" do
          Spree::Zone.match(address).should == second_zone
        end
      end
    end

    context "when there are two qualified zones with different member types" do
      let(:state_zone) { create(:zone, name: 'StateZone') }
      let(:address) { create(:address, country_code: 'US', region_code: 'CT') }

      before { state_zone.members.create(country_code: 'US', region_code: 'CT') }

      it "should return the zone with the more specific member type" do
        Spree::Zone.match(address).should == state_zone
      end
    end

    context "when there are no qualifying zones" do
      it "should return nil" do
        Spree::Zone.match(Spree::Address.new).should be_nil
      end
    end
  end

  context "#country_list" do
    context "when zone consists of countries" do
      let(:country_zone) { create(:zone, name: 'CountryZone') }

      before { country_zone.members.create(country_code: 'CA') }

      it 'should return a list of countries' do
        country_zone.country_list.first.code.should == 'CA'
      end
    end

    context "when zone consists of states" do
      let(:state_zone) { create(:zone, name: 'StateZone') }

      before { state_zone.members.create(country_code: 'AU', region_code: 'NSW') }

      it 'should return a list of countries' do
        state_zone.country_list.first.code.should == 'AU'
      end
    end
  end

  context "#include?" do
    let(:address) { create(:address, region_code: 'CT', country_code: 'US') }

    context "when zone is country type" do
      let(:country_zone) { create(:zone, name: 'CountryZone') }
      before { country_zone.members.create(country_code: 'US') }

      it "should be true" do
        country_zone.include?(address).should be_true
      end
    end

    context "when zone is state type" do
      let(:state_zone) { create(:zone, name: 'StateZone') }
      before { state_zone.members.create(region_code: 'CT', country_code: 'US') }

      it "should be true" do
        state_zone.include?(address).should be_true
      end
    end
  end

  context ".default_tax" do
    context "when there is a default tax zone specified" do
      before { @foo_zone = create(:zone, name: 'whatever', default_tax: true) }

      it "should be the correct zone" do
        foo_zone = create(:zone, name: 'foo')
        Spree::Zone.default_tax.should == @foo_zone
      end
    end

    context "when there is no default tax zone specified" do
      it "should be nil" do
        Spree::Zone.default_tax.should be_nil
      end
    end
  end

  context "#contains?" do
    before do
      @source = create(:zone, name: 'source', zone_members: [])
      @target = create(:zone, name: 'target', zone_members: [])
    end

    context "when the target has no members" do
      before { @source.members.create(country_code: 'US') }

      it "should be false" do
        @source.contains?(@target).should be_false
      end
    end

    context "when the source has no members" do
      before { @target.members.create(country_code: 'CA') }

      it "should be false" do
        @source.contains?(@target).should be_false
      end
    end

    context "when both zones are the same zone" do
      before do
        @source.members.create(country_code: 'US')
        @target = @source
      end

      it "should be true" do
        @source.contains?(@target).should be_true
      end
    end

    context "when both zones are of the same type" do
      before do
        @source.members.create(country_code: 'US')
        @source.members.create(country_code: 'CA')
      end

      context "when all members are included in the zone we check against" do
        before do
          @target.members.create(country_code: 'US')
          @target.members.create(country_code: 'CA')
        end

        it "should be true" do
          @source.contains?(@target).should be_true
        end
      end

      context "when some members are included in the zone we check against" do
        before do
          @target.members.create(country_code: 'US')
          @target.members.create(country_code: 'CA')
          @target.members.create(country_code: 'AU')
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end

      context "when none of the members are included in the zone we check against" do
        before do
          @target.members.create(country_code: 'UK')
          @target.members.create(country_code: 'MX')
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end
    end

    context "when checking country against state" do
      before do
        @source.members.create(country_code: 'US', region_code: 'CT')
        @target.members.create(country_code: 'US')
      end

      it "should be false" do
        @source.contains?(@target).should be_false
      end
    end

    context "when checking state against country" do
      before { @source.members.create(country_code: 'US') }

      context "when all states contained in one of the countries we check against" do

        before do
          @target.members.create(country_code: 'US', region_code: 'CT')
        end

        it "should be true" do
          @source.contains?(@target).should be_true
        end
      end

      context "when some states contained in one of the countries we check against" do

        before do
          @target.members.create(country_code: 'US', region_code: 'CT')
          @target.members.create(country_code: 'CA', region_code: 'AB')
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end

      context "when none of the states contained in any of the countries we check against" do

        before do
          @target.members.create(country_code: 'CA', region_code: 'AB')
          @target.members.create(country_code: 'CA', region_code: 'YT')
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end
    end

  end

  context "#save" do
    context "when default_tax is true" do
      it "should clear previous default tax zone" do
        zone1 = create(:zone, name: 'foo', default_tax: true)
        zone = create(:zone, name: 'bar', default_tax: true)
        zone1.reload.default_tax.should be_false
      end
    end

    context "when a zone member country is added to an existing zone consisting of state members" do
      it "should remove existing state members" do
        zone = create(:zone, name: 'foo', zone_members: [])
        zone.members.create(country_code: 'US', region_code: 'CT')
        country_member = zone.members.create(country_code: 'US')
        zone.save
        zone.reload.members.should == [country_member]
      end
    end
  end

  context "#kind" do
    context "when the zone consists of country zone members" do
      before do
        @zone = create(:zone, name: 'country', zone_members: [])
        @zone.members.create(country_code: 'US')
      end
      it "should return the kind of zone member" do
        @zone.kind.should == "country"
      end
    end

    context "when the zone consists of region zone members" do
      before do
        @zone = create(:zone, name: 'region', zone_members: [])
        @zone.members.create(country_code: 'US', region_code: 'CT')
      end
      it "should return the kind of zone member" do
        @zone.kind.should == "region"
      end
    end
  end
end
