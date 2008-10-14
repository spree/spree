require File.dirname(__FILE__) + '/../spec_helper'

describe Zone do
  before(:each) do
    # has_many_polymorphs requires that the record be saved before you create associations
    @zone = Zone.create
  end
  
  describe "#type" do
    it "should be country when zone contains countries" do
      @zone.countries << mock_model(Country)
      @zone.type.should == "country"
    end
    it "should be state when zone contains states" do
      @zone.states << mock_model(State)
      @zone.type.should == "state"
    end
    it "should be zone when zone contains zones" do
      @zone.zones << mock_model(Zone)
      @zone.type.should == "zone"
    end
    it "should be country when zone contains no members (default)" do
      @zone.type.should == "country"
    end
  end

  describe "#include?" do
    describe "with countries based zone" do 
      it "should return true when the address country is included in the zones list of countries" do
        country = mock_model(Country)
        address = mock_model(Address, :country => country, :null_object => true)
        @zone.countries << country
        @zone.include?(address).should be_true
      end
      it "should return false when the address country is not included in the zones list of countries " do
        country = mock_model(Country)
        address = mock_model(Address, :country => country, :null_object => true)
        @zone.countries << mock_model(Country)
        @zone.include?(address).should be_false
      end
    end
    describe "with states based zone" do 
      it "should return true when the address state is included in the zones list of states" do
        state = mock_model(State)
        address = mock_model(Address, :state => state, :null_object => true)
        @zone.states << state
        @zone.include?(address).should be_true
      end
      it "should return false when the address state is not included in the zones list of states" do
        state = mock_model(State)
        address = mock_model(Address, :state => state, :null_object => true)
        @zone.states << mock_model(State)
        @zone.include?(address).should be_false
      end
    end
    describe "with zones based zone" do
      it "should return true when the address satisfies at least one of the zones in the list of zones" do
        address = mock_model(Address, :null_object => true)
        zone = mock_model(Zone)
        zone.should_receive(:include?).with(address).and_return(true)
        @zone.zones << zone
        @zone.include?(address).should be_true
      end
      it "should return false when the address satisfies none of the zones in the list of zones" do
        address = mock_model(Address, :null_object => true)
        zone = mock_model(Zone)
        zone.should_receive(:include?).with(address).and_return(false)
        @zone.zones << zone
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
    it "should return an empty array if the zone type is state" do
      @zone.stub!(:type).and_return("state")
      @zone.country_list.should == []
    end
    it "should return the corresponding countries if zone type is country" do
      country = mock_model(Country)
      @zone.should_receive(:countries).and_return([country])
      @zone.country_list.should == [country]
    end
    it "should return the countries of the zone children if the type is zone" do
      country1 = mock_model(Country)
      country2 = mock_model(Country)
      zone1 = mock_model(Zone, :country_list => [country1])
      zone2 = mock_model(Zone, :country_list => [country2])
      @zone.stub!(:members).and_return([zone1, zone2])
      @zone.country_list.should == [country1, country2]
    end
  end
end
