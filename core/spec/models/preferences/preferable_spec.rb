require 'spec_helper'

describe Spree::Preferences::Preferable do

  before :all do
    class A
      include Spree::Preferences::Preferable
      attr_reader :id

      def initialize
        @id = rand(999)
      end

      preference :color, :string, :default => :green, :description => "My Favorite Color"
    end

    class B < A
      preference :flavor, :string
    end
  end

  before :each do
    @a = A.new
    @a.stub(:persisted? => true)
    @b = B.new
    @b.stub(:persisted? => true)
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

    it "can be asked and raises" do
      lambda {
        @a.has_preference! :flavor
      }.should raise_error(NoMethodError, "flavor preference not defined")
    end

    it "has a type" do
      @a.preferred_color_type.should eq :string
      @a.preference_type(:color).should eq :string
    end

    it "has a default" do
      @a.preferred_color_default.should eq :green
      @a.preference_default(:color).should eq :green
    end

    it "has a description" do
      @a.preferred_color_description.should eq "My Favorite Color"
      @a.preference_description(:color).should eq "My Favorite Color"
    end

    it "raises if not defined" do
      lambda {
        @a.get_preference :flavor
      }.should raise_error(NoMethodError, "flavor preference not defined")
    end

  end

  describe "preference access" do
    it "handles ghost methods for preferences" do
      #pending("TODO: cmar to look at this test to figure out why it's failing on 1.9")
      @a.preferred_color = :blue
      @a.preferred_color.should eq :blue

      @a.prefers_color = :green
      @a.prefers_color?.should eq :green
    end

    it "has genric readers" do
      @a.preferred_color = :red
      @a.prefers?(:color).should eq :red
      @a.preferred(:color).should eq :red
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

    context "converts boolean preferences to boolean values" do
      before do
        A.preference :is_boolean, :boolean, :default => true
      end

      it "with strings" do
        @a.set_preference(:is_boolean, '0')
        @a.preferences[:is_boolean].should be_false
      end
    end

  end

  describe "persisted preferables" do
    before(:all) do
      class CreatePrefTest < ActiveRecord::Migration
        def self.up
          create_table :pref_tests do |t|
            t.string :col
          end
        end

        def self.down
          drop_table :pref_tests
        end
      end

      @@migration_verbosity = ActiveRecord::Migration.verbose
      ActiveRecord::Migration.verbose = false
      CreatePrefTest.migrate(:up)

      class PrefTest < ActiveRecord::Base  
        preference :pref_test_pref, :string, :default => 'abc'
      end
    end

    after(:all) do
      CreatePrefTest.migrate(:down)
      ActiveRecord::Migration.verbose = @@migration_verbosity
    end
      
    before(:each) do
      @pt = PrefTest.new
    end

    it "clear preferences" do
      @pt.set_preference(:pref_test_pref, 'xyz')
      @pt.preferred_pref_test_pref.should == 'xyz'
      @pt.clear_preferences
      @pt.preferred_pref_test_pref.should == 'abc'
    end      

    it "clear preferences when record is deleted" do
      @pt.save!
      @pt.preferred_pref_test_pref = 'lmn'
      @pt.save!
      @pt.destroy
      @pt1 = PrefTest.new(:col => 'aaaa')
      @pt1.id = @pt.id
      @pt1.save!
      @pt1.get_preference(:pref_test_pref).should_not == 'lmn'
      @pt1.get_preference(:pref_test_pref).should == 'abc'
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
    @a.respond_to?(:preferred_test_temp).should be_false
  end
end


