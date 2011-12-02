require 'spec_helper'

describe Spree::Preferences::Preferable do

  before :all do
    class A
      include Spree::Preferences::Preferable
      attr_reader :id

      def initialize
        @id = rand(999)
      end

      preference :color, :string, :default => :green
    end

    class B < A
      preference :flavor, :string
    end
  end

  before :each do
    @a = A.new
    @b = B.new
  end

  describe "preference definitions" do
    it "parent should not see child definitions" do
      @a.has_preference?(:color).should be_true
      @a.has_preference?(:flavor).should_not be_true
    end

    it "child should have parent and own definitions" do
      @b.has_preference?(:color).should be_true
      @b.has_preference?(:flavor).should be_true
    end

    it "instances have defaults" do
      @a.preferred_color.should eq :green
      @b.preferred_color.should eq :green
      @b.preferred_flavor.should be_nil
    end

    it "can be asked if it has a preference definition" do
      @a.has_preference?(:color).should be_true
      @a.has_preference?(:bad).should be_false
    end
  end

  describe "preference access" do
    it "handles ghost methods for preferences" do
      pending("TODO: cmar to look at this test to figure out why it's failing on 1.9")
      @a.preferred_color = :blue
      @a.preferred_color.should eq :blue

      @a.prefers_color = :green
      @a.prefers_color?(:green).should be_true
    end

    it "parent and child instances have their own prefs" do
      @a.preferred_color = :red
      @b.preferred_color = :blue

      @a.preferred_color.should eq :red
      @b.preferred_color.should eq :blue
    end

    it "raises when preference not defined" do
      lambda {
        @a.set_preference(:bad, :bone)
      }.should raise_exception(NoMethodError, "bad preference not defined")
    end

    it "builds a hash of preferences" do
      @b.preferred_flavor = :strawberry
      @b.preferences[:flavor].should eq :strawberry
      @b.preferences[:color].should eq :green #default from A
    end

  end

  it "builds cache keys" do
    @a.preference_cache_key(:color).should match /a\/color\/\d+/
  end

  it "can add and remove preferences" do
    A.preference :test_temp, :boolean, :default => true
    @a.preferred_test_temp.should be_true
    A.remove_preference :test_temp
    @a.has_preference?(:test_temp).should be_false
    @a.respond_to?(:prferred_test_temp).should be_false
  end
end


