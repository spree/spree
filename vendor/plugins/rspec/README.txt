= RSpec

* http://rspec.info
* http://rubyforge.org/projects/rspec
* http://github.com/dchelimsky/rspec/wikis
* mailto:rspec-devel@rubyforge.org

== DESCRIPTION:

RSpec is a Behaviour Driven Development framework for writing executable code
examples.

== FEATURES:

* Spec::Example provides a framework for expressing executable code examples
* Spec::Expectations adds #should and #should_not to every object
* Spec::Matchers provides Expression Matchers for use with #should and #should_not
* Spec::Mocks is a full featured mocking/stubbing library

== SYNOPSIS:

  describe Account do
    context "transfering money" do
      it "deposits transfer amount to the other account" do
        source = Account.new(50, :USD)
        target = mock('target account')
        target.should_receive(:deposit).with(Money.new(5, :USD))
        source.transfer(5, :USD).to(target)
      end

      it "reduces its balance by the transfer amount" do
        source = Account.new(50, :USD)
        target = stub('target account')
        source.transfer(5, :USD).to(target)
        source.balance.should == Money.new(45, :USD)
      end
    end
  end
  
  $ spec spec/account_spec.rb --format nested
  Account
    transfering money
      deposits transfer amount to the other account
      reduces its balance by the transfer amount
    
  2 examples, 0 failures

== INSTALL:

  [sudo] gem install rspec

 or

  git clone git://github.com/dchelimsky/rspec.git
  cd rspec
  rake gem
  rake install_gem
