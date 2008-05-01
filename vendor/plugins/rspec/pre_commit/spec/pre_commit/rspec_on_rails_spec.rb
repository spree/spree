require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'fileutils'

include FileUtils

##
# This is not a complete specification of PreCommit.RSpecOnRails, but 
# just a collection of bug fix regression tests.
describe "RSpecOnRails pre_commit" do
  before do
    @original_dir = File.expand_path(FileUtils.pwd)
    @rails_app_dir = File.expand_path(File.dirname(__FILE__) + "/../../../example_rails_app/")

    Dir.chdir(@rails_app_dir)
    rm_rf('vendor/plugins/rspec_on_rails')
    system("svn export ../rspec_on_rails vendor/plugins/rspec_on_rails")

    @pre_commit = PreCommit::RspecOnRails.new(nil)
  end

  after do
    rm('db/migrate/888_create_purchases.rb', :force => true)
    @pre_commit.destroy_purchase
    Dir.chdir(@original_dir)
  end

  # bug in r1802
  it "should fail noisily if there is a migration name conflict" do
    touch('db/migrate/888_create_purchases.rb')
    lambda { @pre_commit.generate_purchase }.should raise_error
  end

  it "should not fail if tests run ok" do
    lambda { @pre_commit.generate_purchase }.should_not raise_error
  end
end
