require File.dirname(__FILE__) + '/../../../spec_helper.rb'

describe "c" do

  it "1" do
  end

  it "2" do
  end

end

describe "d" do

  it "3" do
  end

  it "4" do
  end

end

class SpecParserSubject
end

describe SpecParserSubject do

  it "5" do
  end

end

describe SpecParserSubject, "described" do

  it "6" do
  end

end

describe SpecParserSubject, "described", :something => :something_else do

   it "7" do
   end

end

describe "described", :something => :something_else do

  it "8" do
  end

end

describe "e" do

  it "9" do
  end

  it "10" do
  end

  describe "f" do
    it "11" do
    end

    it "12" do
    end
  end

end
