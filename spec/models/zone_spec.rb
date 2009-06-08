require File.dirname(__FILE__) + '/../spec_helper'

describe Zone do
  before(:each) do
    # has_many_polymorphs requires that the record be saved before you create associations
    @zone = Zone.create(:name => "foo", :description => "foofah")
  end
  
  describe "#kind" do
    it "should be country when zone contains countries" do
      @zone.members << ZoneMember.new(:zoneable => Country.new)
      @zone.kind.should == "country"
    end
    it "should be state when zone contains states" do
      @zone.members << ZoneMember.new(:zoneable => State.new)
      @zone.kind.should == "state"
    end
    it "should be zone when zone contains zones" do
      @zone.members << ZoneMember.new(:zoneable => Zone.new)
      @zone.kind.should == "zone"
    end
    it "should be country when zone contains no members (default)" do
      @zone.kind.should == "country"
    end
  end

  describe "#include?" do
    describe "with countries based zone" do 
      it "should return true when the address country is included in the zones list of countries" do
        country = Country.new
        address = Address.new(:country => country)
        @zone.members << ZoneMember.new(:zoneable => country)
        @zone.include?(address).should be_true
      end
      it "should return false when the address country is not included in the zones list of countries " do
        country = Country.new
        address = Address.new(:country => country)
        @zone.members << ZoneMember.new(:zoneable => Country.new)
        @zone.include?(address).should be_false
      end
    end
    describe "with states based zone" do   
      it "should return true when the address state is included in the zones list of states" do
        state = State.new
        address = Address.new(:state => state)
        @zone.members << ZoneMember.new(:zoneable => state)
        @zone.include?(address).should be_true
      end
      it "should return false when the address state is not included in the zones list of states" do
        state = State.new
        address = Address.new(:state => state)
        @zone.members << ZoneMember.new(:zoneable => Address.new)
        @zone.include?(address).should be_false
      end
    end
    describe "with zones based zone" do               
      it "should return true when the address satisfies at least one of the zones in the list of zones" do
        address = Address.new
        @zone.should_receive(:include?).with(address).and_return(true)
        @zone.members << ZoneMember.new(:zoneable => @zone)
        @zone.include?(address).should be_true
      end
      it "should return false when the address satisfies none of the zones in the list of zones" do
        address = Address.new
        @zone.should_receive(:include?).with(address).and_return(false)
        @zone.members << ZoneMember.new(:zoneable => @zone)
        @zone.include?(address).should be_false
      end
    end
  end

  describe "match" do
    
    before :each do
      @address = mock_model(Address)
    end
    
    it "should return an empty array if there are no zone" do
      Zone.should_receive(:all).and_return([])
      Zone.match(@address).should == []
    end
    
    it "should return only one zone if the address matches only one zone" do
      zone1 = mock_model(Zone)
      zone1.should_receive(:include?).with(@address).and_return(true)
      zone2 = mock_model(Zone)
      zone2.should_receive(:include?).with(@address).and_return(false)
      Zone.should_receive(:all).and_return([zone1, zone2])
      Zone.match(@address).should == [zone1]
    end

    it "should return both zones if the address matches both zones" do
      zone1 = mock_model(Zone)
      zone1.should_receive(:include?).with(@address).and_return(true)
      zone2 = mock_model(Zone)
      zone2.should_receive(:include?).with(@address).and_return(true)
      Zone.should_receive(:all).and_return([zone1, zone2])
      Zone.match(@address).should == [zone1, zone2]
    end

    it "should return no zones if address matches neither of the zones" do
      zone1 = mock_model(Zone)
      zone1.should_receive(:include?).with(@address).and_return(false)
      zone2 = mock_model(Zone)
      zone2.should_receive(:include?).with(@address).and_return(false)
      Zone.should_receive(:all).and_return([zone1, zone2])
      Zone.match(@address).should == []
    end

  end
  
  describe "country_list" do
    it "should return an empty array if the zone kind is state" do
      @zone.stub!(:kind, :return => "state")
      @zone.country_list.should == []
    end
    it "should return the corresponding countries if zone kind is country" do
      country = Country.new
      @zone.members << ZoneMember.new(:zoneable => country)
      @zone.country_list.should == [country]
    end
    it "should return the countries of the zone children if the kind is zone" do   
      country1 = Country.new
      country2 = Country.new
      
      zone1 = Zone.new
      zone1.members << ZoneMember.new(:zoneable => country1)
      
      zone2 = Zone.new
      zone2.members << ZoneMember.new(:zoneable => country2)
      
      @zone.members << ZoneMember.new(:zoneable => zone1)
      @zone.members << ZoneMember.new(:zoneable => zone2)
      @zone.country_list.should == [country1, country2]
    end
  end
end
