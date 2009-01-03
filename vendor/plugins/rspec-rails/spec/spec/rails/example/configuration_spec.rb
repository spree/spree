require File.dirname(__FILE__) + '/../../../spec_helper'

module Spec
  module Runner
    describe Configuration do

      def config
        @config ||= Configuration.new
      end

      describe "#use_transactional_fixtures" do
        it "should return #{Spec::Runner::Configuration::TEST_CASE}.use_transactional_fixtures" do
          config.use_transactional_fixtures.should == Spec::Runner::Configuration::TEST_CASE.use_transactional_fixtures
        end

        it "should set #{Spec::Runner::Configuration::TEST_CASE}.use_transactional_fixtures to false" do
          Configuration::EXAMPLE_GROUP_CLASSES.each do |example_group|
            example_group.should_receive(:use_transactional_fixtures=).with(false)
          end
          config.use_transactional_fixtures = false
        end

        it "should set #{Spec::Runner::Configuration::TEST_CASE}.use_transactional_fixtures to true" do
          Configuration::EXAMPLE_GROUP_CLASSES.each do |example_group|
            example_group.should_receive(:use_transactional_fixtures=).with(true)
          end
          config.use_transactional_fixtures = true
        end
      end

      describe "#use_instantiated_fixtures" do
        it "should return #{Spec::Runner::Configuration::TEST_CASE}.use_transactional_fixtures" do
          config.use_instantiated_fixtures.should == Spec::Runner::Configuration::TEST_CASE.use_instantiated_fixtures
        end

        it "should set #{Spec::Runner::Configuration::TEST_CASE}.use_instantiated_fixtures to false" do
          Configuration::EXAMPLE_GROUP_CLASSES.each do |example_group|
            example_group.should_receive(:use_instantiated_fixtures=).with(false)
          end
          config.use_instantiated_fixtures = false
        end

        it "should set #{Spec::Runner::Configuration::TEST_CASE}.use_instantiated_fixtures to true" do
          Configuration::EXAMPLE_GROUP_CLASSES.each do |example_group|
            example_group.should_receive(:use_instantiated_fixtures=).with(true)
          end
          config.use_instantiated_fixtures = true
        end
      end

      describe "#fixture_path" do
        it "should default to RAILS_ROOT + '/spec/fixtures'" do
          config.fixture_path.should == RAILS_ROOT + '/spec/fixtures'
          Configuration::EXAMPLE_GROUP_CLASSES.each do |example_group|
            example_group.fixture_path.should == RAILS_ROOT + '/spec/fixtures'
          end
        end

        it "should set fixture_path" do
          config.fixture_path = "/new/path"
          config.fixture_path.should == "/new/path"
          Configuration::EXAMPLE_GROUP_CLASSES.each do |example_group|
            example_group.fixture_path.should == "/new/path"
          end
        end
      end

      describe "#global_fixtures" do
        it "should set fixtures on TestCase" do
          Configuration::EXAMPLE_GROUP_CLASSES.each do |example_group|
            example_group.should_receive(:fixtures).with(:blah)
          end
          config.global_fixtures = [:blah]
        end
      end
      
    end
  end
end
