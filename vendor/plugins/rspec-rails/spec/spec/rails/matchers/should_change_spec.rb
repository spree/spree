require File.dirname(__FILE__) + '/../../../spec_helper'

describe "should change" do
  describe "handling association proxies" do
    it "should match expected collection with proxied collection" do
      person = Person.create!(:name => 'David')
      koala = person.animals.create!(:name => 'Koala')
      zebra = person.animals.create!(:name => 'Zebra')
      
      lambda {
        person.animals.delete(koala)
      }.should change{person.animals}.to([zebra])
    end
  end
end