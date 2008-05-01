require File.dirname(__FILE__) + '/story_helper'

module Spec
  module Story
    describe Step, "matching" do
      it "should match a text string" do
        step = Step.new("this text") {}
        step.matches?("this text").should be_true
      end
      
      it "should not match a text string that does not start the same" do
        step = Step.new("this text") {}
        step.matches?("Xthis text").should be_false
      end
      
      it "should not match a text string that does not end the same" do
        step = Step.new("this text") {}
        step.matches?("this textX").should be_false
      end
      
      it "should match a text string with a param" do
        step = Step.new("this $param text") {}
        step.matches?("this anything text").should be_true
      end
      
      it "should not be greedy" do
        step = Step.new("enter $value for $key") {}
        step.parse_args("enter 3 for keys for a piano").should == ['3','keys for a piano']
      end
      
      it "should match a text string with 3 params" do
        step = Step.new("1 $one 2 $two 3 $three 4") {}
        step.matches?("1 a 2 b 3 c 4").should be_true
      end
      
      it "should match a text string with a param at the beginning" do
        step = Step.new("$one 2 3") {}
        step.matches?("a 2 3").should be_true
      end
      
      it "should match a text string with a param at the end" do
        step = Step.new("1 2 $three") {}
        step.matches?("1 2 c").should be_true
      end
      
      it "should not match a different string" do
        step = Step.new("this text") {}
        step.matches?("other text").should be_false
      end

      it "should match a regexp" do
        step = Step.new(/this text/) {}
        step.matches?("this text").should be_true
      end
      
      it "should match a regexp with a match group" do
        step = Step.new(/this (.*) text/) {}
        step.matches?("this anything text").should be_true
      end
      
      it "should match a regexp with a named variable" do
        step = Step.new(/this $variable text/) {}
        step.matches?("this anything text").should be_true
      end
      
      it "should not match a non matching regexp" do
        step = Step.new(/this (.*) text/) {}
        step.matches?("other anything text").should be_false
      end
      
      it "should not match a non matching regexp with a named variable" do
        step = Step.new(/this $variable text/) {}
        step.matches?("other anything text").should be_false
      end
      
      it "should not get bogged down by parens in strings" do
        step = Step.new("before () after") {}
        step.matches?("before () after").should be_true
      end
      
      it "should match any option of an alteration" do
        step = Step.new(/(he|she) is cool/) {}
        step.matches?("he is cool").should be_true
        step.matches?("she is cool").should be_true
      end
      
      it "should match alteration as well as a variable" do
        step = Step.new(/(he|she) is (.*)/) {}
        step.matches?("he is cool").should be_true
        step.parse_args("he is cool").should == ['he', 'cool']
      end
      
      it "should match alteration as well as a named variable" do
        step = Step.new(/(he|she) is $adjective/) {}
        step.matches?("he is cool").should be_true
        step.parse_args("he is cool").should == ['he', 'cool']
      end
      
      it "should match alteration as well as a anonymous and named variable" do
        step = Step.new(/(he|she) is (.*?) $adjective/) {}
        step.matches?("he is very cool").should be_true
        step.parse_args("he is very cool").should == ['he', 'very', 'cool']
      end
      
    end
    
    describe Step do
      it "should make complain with no block" do
        lambda {
          step = Step.new("foo")
        }.should raise_error
      end
      
      it "should perform itself on an object" do
        # given
        $instance = nil
        step = Step.new 'step' do
          $instance = self
        end
        instance = Object.new
        
        # when
        step.perform(instance, "step")
        
        # then
        $instance.should == instance
      end
      
      it "should perform itself with one parameter with match expression" do
        # given
        $result = nil
        step = Step.new 'an account with $count dollars' do |count|
          $result = count
        end
        instance = Object.new
        
        # when
        args = step.parse_args("an account with 3 dollars")
        step.perform(instance, *args)
        
        # then
        $result.should == "3"
      end
      
      it "should perform itself with one parameter without a match expression" do
        # given
        $result = nil
        step = Step.new 'an account with a balance of' do |amount|
          $result = amount
        end
        instance = Object.new
        
        # when
        step.perform(instance, 20)
        
        # then
        $result.should == 20
      end
      
      it "should perform itself with 2 parameters" do
        # given
        $account_type = nil
        $amount = nil
        step = Step.new 'a $account_type account with $amount dollars' do |account_type, amount|
          $account_type = account_type
          $amount = amount
        end
        instance = Object.new
        
        # when
        args = step.parse_args("a savings account with 3 dollars")
        step.perform(instance, *args)
        
        # then
        $account_type.should == "savings"
        $amount.should == "3"
      end

      it "should perform itself when defined with a regexp with 2 parameters" do
        # given
        $pronoun = nil
        $adjective = nil
        step = Step.new /(he|she) is (.*)/ do |pronoun, adjective|
          $pronoun = pronoun
          $adjective = adjective
        end
        instance = Object.new
        
        # when
        args = step.parse_args("he is cool")
        step.perform(instance, *args)
        
        # then
        $pronoun.should == "he"
        $adjective.should == "cool"
      end

    end
  end
end
