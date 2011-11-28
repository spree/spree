require 'spec_helper'

describe Spree::Zone do
  let(:country) { Factory :country }
  let(:state)   { Factory(:state, :country => country) }
  let(:address) { Factory(:address, :state => state) }

  #context 'factory' do
    #let(:zone) { Spree::Zone.create :name => "FooZone" }
    #it "should set zone members correctly" do
      #zone.zone_members.count.should == 1
    #end
  #end

  context "#destroy" do
    let(:zone) { Spree::Zone.create :name => "FooZone" }

    it "should destroy all zone members" do
      zone.destroy
      zone.zone_members.count.should == 0
    end
  end

  context "#match" do
    let(:country_zone) { Spree::Zone.create :name => "CountryZone" }
    let(:country) { Factory :country }

    before { country_zone.members.create(:zoneable => country) }

    context "when there is only one qualifying zone" do
      let(:address) { Factory(:address, :country => country) }

      it "should return the qualifying zone" do
        Spree::Zone.match(address).should == country_zone
      end
    end

    context "when there are two qualified zones with same member type" do
      let(:address) { Factory(:address, :country => country) }
      let(:second_zone) { Spree::Zone.create :name => "SecondZone" }

      before { second_zone.members.create(:zoneable => country) }
      it "should return the zone that was created first" do
        Spree::Zone.match(address).should == country_zone
      end
    end

    context "when there are two qualified zones with different member types" do
      let(:state_zone) { Spree::Zone.create :name => "StateZone" }
      let(:state) { Factory :state }
      let(:address) { Factory(:address, :country => country, :state => state) }

      before { state_zone.members.create(:zoneable => state) }

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

  context ".match" do
    it 'should return zones that include the address' do
      other_zone = Factory(:zone)
      zone.zone_members = [Spree::ZoneMember.create(:zoneable => state)]
      Spree::Zone.match(address).should == [zone]
    end
  end

  context "#include?" do
    context "given a zone of countries" do
      it 'should include the address' do
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => country)]
        zone.include?(address).should be_true
      end
    end

    context "given a zone of states" do
      it 'should include the address' do
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => state)]
        zone.include?(address).should be_true
      end
    end

    context "given a zone of zones" do
      it 'should include the address' do
        sub_zone = Factory.build(:zone, :zone_members => [Spree::ZoneMember.create(:zoneable => country)])
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => sub_zone)]
        zone.include?(address).should be_true
      end
    end
  end

  context "#kind" do
    context "given a zone of countries" do
      it 'should be type of country' do
        zone.kind.should == 'country'
      end
    end

    context "given a zone of states" do
      it 'should be type of state' do
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => state)]
        zone.kind.should == 'state'
      end
    end

    context "given a zone of zones" do
      it 'should be type of zone' do
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => Factory.build(:zone))]
        zone.kind.should == 'zone'
      end
    end
  end

  context "#country_list" do
    context "given a zone of countries" do
      it 'should return a list of countries' do
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => country)]
        zone.country_list.should == [country]
      end
    end

    context "given a zone of states" do
      it 'should return a list of countries that states belongs to' do
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => state)]
        zone.country_list.should == [state.country]
      end
    end

    context "given a zone of zones" do
      it 'should return a list of countries belong to the children zones' do
        sub_zone = Factory.build(:zone, :zone_members => [Spree::ZoneMember.create(:zoneable => country)])
        zone.zone_members = [Spree::ZoneMember.create(:zoneable => sub_zone)]
        zone.country_list.should == [country]
      end
    end
  end
end
