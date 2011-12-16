require 'spec_helper'

describe Spree::Zone do
  context "#destroy" do
    let(:zone) { Spree::Zone.create :name => "FooZone" }

    it "should destroy all zone members" do
      zone.destroy
      zone.zone_members.count.should == 0
    end
  end

  context "#match" do
    let(:country_zone) { Spree::Zone.create :name => "CountryZone" }
    let(:country) do
      country = Factory(:country)
      # Create at least one state for this country
      state = Factory(:state, :country => country)
      country
    end

    before { country_zone.members.create(:zoneable => country) }

    context "when there is only one qualifying zone" do
      let(:address) { Factory(:address, :country => country, :state => country.states.first) }

      it "should return the qualifying zone" do
        Spree::Zone.match(address).should == country_zone
      end
    end

    context "when there are two qualified zones with same member type" do
      let(:address) { Factory(:address, :country => country, :state => country.states.first) }
      let(:second_zone) { Spree::Zone.create :name => "SecondZone" }

      before { second_zone.members.create(:zoneable => country) }
      it "should return the zone that was created first" do
        Spree::Zone.match(address).should == country_zone
      end
    end

    context "when there are two qualified zones with different member types" do
      let(:state_zone) { Spree::Zone.create :name => "StateZone" }
      let(:address) { Factory(:address, :country => country, :state => country.states.first) }

      before { state_zone.members.create(:zoneable => country.states.first) }

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

  context ".default_tax" do
    context "when :default_tax_zone preference is specified" do
      before { Spree::Config.set(:default_tax_zone => "foo") }

      it "should be the correct zone if a zone exists with that name" do
        foo_zone = Factory(:zone, :name => "foo")
        Spree::Zone.default_tax.should == foo_zone
      end

      it "should be nil if no zone exists with that name" do
        bar_zone = Factory(:zone, :name => "bar")
        Spree::Zone.default_tax.should be_nil
      end

      it "should be nil if no zones exist" do
        Spree::Zone.default_tax.should be_nil
      end
    end

    context "when :default_tax_zone preference is nil" do
      before { Spree::Config.set(:default_tax_zone => nil) }

      it "should be_nil" do
        Spree::Zone.default_tax.should be_nil
      end
    end
  end

  context "#contains?" do
    let(:country1) { Factory(:country) }
    let(:country2) { Factory(:country) }
    let(:country3) { Factory(:country) }

    before do
      @source = Spree::Zone.create(:name => 'source')
      @target = Spree::Zone.create(:name => 'target')
    end

    context "when the target has no members" do
      before { @source.members.create(:zoneable => country1) }

      it "should be false" do
        @source.contains?(@target).should be_false
      end
    end

    context "when the source has no members" do
      before { @target.members.create(:zoneable => country1) }

      it "should be false" do
        @source.contains?(@target).should be_false
      end
    end

    context "when both zones are of the same type" do
      before do
        @source.members.create(:zoneable => country1)
        @source.members.create(:zoneable => country2)
      end

      context "when all members are included in the zone we check against" do
        before do
          @target.members.create(:zoneable => country1)
          @target.members.create(:zoneable => country2)
        end

        it "should be true" do
          @source.contains?(@target).should be_true
        end
      end

      context "when some members are included in the zone we check against" do
        before do
          @target.members.create(:zoneable => country1)
          @target.members.create(:zoneable => country2)
          @target.members.create(:zoneable => Factory(:country))
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end

      context "when none of the members are included in the zone we check against" do
        before do
          @target.members.create(:zoneable => Factory(:country))
          @target.members.create(:zoneable => Factory(:country))
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end
    end

    context "when checking country against state" do
      before do
        @source.members.create(:zoneable => Factory(:state))
        @target.members.create(:zoneable => country1)
      end

      it "should be false" do
        @source.contains?(@target).should be_false
      end
    end

    context "when checking state against country" do
      before { @source.members.create(:zoneable => country1) }

      context "when all states contained in one of the countries we check against" do

        before do
          state1 = Factory(:state, :country => country1)
          @target.members.create(:zoneable => state1)
        end

        it "should be true" do
          @source.contains?(@target).should be_true
        end
      end

      context "when some states contained in one of the countries we check against" do

        before do
          state1 = Factory(:state, :country => country1)
          @target.members.create(:zoneable => state1)
          @target.members.create(:zoneable => Factory(:state, :country => country2))
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end

      context "when none of the states contained in any of the countries we check against" do

        before do
          @target.members.create(:zoneable => Factory(:state, :country => country2))
          @target.members.create(:zoneable => Factory(:state, :country => country2))
        end

        it "should be false" do
          @source.contains?(@target).should be_false
        end
      end
    end

  end

end
