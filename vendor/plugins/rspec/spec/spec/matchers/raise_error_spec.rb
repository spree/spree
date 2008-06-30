require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "should raise_error" do
  it "should pass if anything is raised" do
    lambda {raise}.should raise_error
  end
  
  it "should fail if nothing is raised" do
    lambda {
      lambda {}.should raise_error
    }.should fail_with("expected Exception but nothing was raised")
  end
end

describe "should_not raise_error" do
  it "should pass if nothing is raised" do
    lambda {}.should_not raise_error
  end
  
  it "should fail if anything is raised" do
    lambda {
      lambda {raise}.should_not raise_error
    }.should fail_with("expected no Exception, got RuntimeError")
  end
end

describe "should raise_error(message)" do
  it "should pass if RuntimeError is raised with the right message" do
    lambda {raise 'blah'}.should raise_error('blah')
  end
  it "should pass if RuntimeError is raised with a matching message" do
    lambda {raise 'blah'}.should raise_error(/blah/)
  end
  it "should pass if any other error is raised with the right message" do
    lambda {raise NameError.new('blah')}.should raise_error('blah')
  end
  it "should fail if RuntimeError error is raised with the wrong message" do
    lambda do
      lambda {raise 'blarg'}.should raise_error('blah')
    end.should fail_with("expected Exception with \"blah\", got #<RuntimeError: blarg>")
  end
  it "should fail if any other error is raised with the wrong message" do
    lambda do
      lambda {raise NameError.new('blarg')}.should raise_error('blah')
    end.should fail_with("expected Exception with \"blah\", got #<NameError: blarg>")
  end
end

describe "should_not raise_error(message)" do
  it "should pass if RuntimeError error is raised with the different message" do
    lambda {raise 'blarg'}.should_not raise_error('blah')
  end
  it "should pass if any other error is raised with the wrong message" do
    lambda {raise NameError.new('blarg')}.should_not raise_error('blah')
  end
  it "should fail if RuntimeError is raised with message" do
    lambda do
      lambda {raise 'blah'}.should_not raise_error('blah')
    end.should fail_with(%Q|expected no Exception with "blah", got #<RuntimeError: blah>|)
  end
  it "should fail if any other error is raised with message" do
    lambda do
      lambda {raise NameError.new('blah')}.should_not raise_error('blah')
    end.should fail_with(%Q|expected no Exception with "blah", got #<NameError: blah>|)
  end
end

describe "should raise_error(NamedError)" do
  it "should pass if named error is raised" do
    lambda { non_existent_method }.should raise_error(NameError)
  end
  
  it "should fail if nothing is raised" do
    lambda {
      lambda { }.should raise_error(NameError)
    }.should fail_with("expected NameError but nothing was raised")
  end
  
  it "should fail if another error is raised (NameError)" do
    lambda {
      lambda { raise }.should raise_error(NameError)
    }.should fail_with("expected NameError, got RuntimeError")
  end
  
  it "should fail if another error is raised (NameError)" do
    lambda {
      lambda { load "non/existent/file" }.should raise_error(NameError)
    }.should fail_with(/expected NameError, got #<LoadError/)
  end
end

describe "should_not raise_error(NamedError)" do
  it "should pass if nothing is raised" do
    lambda { }.should_not raise_error(NameError)
  end
  
  it "should pass if another error is raised" do
    lambda { raise }.should_not raise_error(NameError)
  end
  
  it "should fail if named error is raised" do
    lambda {
      lambda { non_existent_method }.should_not raise_error(NameError)
    }.should fail_with(/expected no NameError, got #<NameError: undefined/)
  end  
end

describe "should raise_error(NamedError, error_message) with String" do
  it "should pass if named error is raised with same message" do
    lambda { raise "example message" }.should raise_error(RuntimeError, "example message")
  end
  
  it "should fail if nothing is raised" do
    lambda {
      lambda {}.should raise_error(RuntimeError, "example message")
    }.should fail_with("expected RuntimeError with \"example message\" but nothing was raised")
  end
  
  it "should fail if incorrect error is raised" do
    lambda {
      lambda { raise }.should raise_error(NameError, "example message")
    }.should fail_with("expected NameError with \"example message\", got RuntimeError")
  end
  
  it "should fail if correct error is raised with incorrect message" do
    lambda {
      lambda { raise RuntimeError.new("not the example message") }.should raise_error(RuntimeError, "example message")
    }.should fail_with(/expected RuntimeError with \"example message\", got #<RuntimeError: not the example message/)
  end
end

describe "should raise_error(NamedError, error_message) { |err| ... }" do
  it "should yield exception if named error is raised with same message" do
    ran = false

    lambda {
      raise "example message"
    }.should raise_error(RuntimeError, "example message") { |err|
      ran = true
      err.class.should == RuntimeError
      err.message.should == "example message"
    }

    ran.should == true
  end

  it "yielded block should be able to fail on it's own right" do
    ran, passed = false, false

    lambda {
      lambda {
        raise "example message"
      }.should raise_error(RuntimeError, "example message") { |err|
        ran = true
        5.should == 4
        passed = true
      }
    }.should fail_with(/expected: 4/m)

    ran.should == true
    passed.should == false
  end

  it "should NOT yield exception if no error was thrown" do
    ran = false

    lambda {
      lambda {}.should raise_error(RuntimeError, "example message") { |err|
        ran = true
      }
    }.should fail_with("expected RuntimeError with \"example message\" but nothing was raised")

    ran.should == false
  end

  it "should not yield exception if error class is not matched" do
    ran = false

    lambda {
      lambda {
        raise "example message"
      }.should raise_error(SyntaxError, "example message") { |err|
        ran = true
      }
    }.should fail_with("expected SyntaxError with \"example message\", got #<RuntimeError: example message>")

    ran.should == false
  end

  it "should NOT yield exception if error message is not matched" do
    ran = false

    lambda {
      lambda {
        raise "example message"
      }.should raise_error(RuntimeError, "different message") { |err|
        ran = true
      }
    }.should fail_with("expected RuntimeError with \"different message\", got #<RuntimeError: example message>")

    ran.should == false
  end
end

describe "should_not raise_error(NamedError, error_message) { |err| ... }" do
  it "should pass if nothing is raised" do
    ran = false

    lambda {}.should_not raise_error(RuntimeError, "example message") { |err|
      ran = true
    }

    ran.should == false
  end

  it "should pass if a different error is raised" do
    ran = false

    lambda { raise }.should_not raise_error(NameError, "example message") { |err|
      ran = true
    }

    ran.should == false
  end

  it "should pass if same error is raised with different message" do
    ran = false

    lambda {
      raise RuntimeError.new("not the example message")
    }.should_not raise_error(RuntimeError, "example message") { |err|
      ran = true
    }

    ran.should == false
  end

  it "should fail if named error is raised with same message" do
    ran = false

    lambda {
      lambda {
        raise "example message"
      }.should_not raise_error(RuntimeError, "example message") { |err|
        ran = true
      }
    }.should fail_with("expected no RuntimeError with \"example message\", got #<RuntimeError: example message>")

    ran.should == false
  end
end

describe "should_not raise_error(NamedError, error_message) with String" do
  it "should pass if nothing is raised" do
    lambda {}.should_not raise_error(RuntimeError, "example message")
  end
  
  it "should pass if a different error is raised" do
    lambda { raise }.should_not raise_error(NameError, "example message")
  end
  
  it "should pass if same error is raised with different message" do
    lambda { raise RuntimeError.new("not the example message") }.should_not raise_error(RuntimeError, "example message")
  end
  
  it "should fail if named error is raised with same message" do
    lambda {
      lambda { raise "example message" }.should_not raise_error(RuntimeError, "example message")
    }.should fail_with("expected no RuntimeError with \"example message\", got #<RuntimeError: example message>")
  end
end

describe "should raise_error(NamedError, error_message) with Regexp" do
  it "should pass if named error is raised with matching message" do
    lambda { raise "example message" }.should raise_error(RuntimeError, /ample mess/)
  end
  
  it "should fail if nothing is raised" do
    lambda {
      lambda {}.should raise_error(RuntimeError, /ample mess/)
    }.should fail_with("expected RuntimeError with message matching /ample mess/ but nothing was raised")
  end
  
  it "should fail if incorrect error is raised" do
    lambda {
      lambda { raise }.should raise_error(NameError, /ample mess/)
    }.should fail_with("expected NameError with message matching /ample mess/, got RuntimeError")
  end
  
  it "should fail if correct error is raised with incorrect message" do
    lambda {
      lambda { raise RuntimeError.new("not the example message") }.should raise_error(RuntimeError, /less than ample mess/)
    }.should fail_with("expected RuntimeError with message matching /less than ample mess/, got #<RuntimeError: not the example message>")
  end
end

describe "should_not raise_error(NamedError, error_message) with Regexp" do
  it "should pass if nothing is raised" do
    lambda {}.should_not raise_error(RuntimeError, /ample mess/)
  end
  
  it "should pass if a different error is raised" do
    lambda { raise }.should_not raise_error(NameError, /ample mess/)
  end
  
  it "should pass if same error is raised with non-matching message" do
    lambda { raise RuntimeError.new("non matching message") }.should_not raise_error(RuntimeError, /ample mess/)
  end
  
  it "should fail if named error is raised with matching message" do
    lambda {
      lambda { raise "example message" }.should_not raise_error(RuntimeError, /ample mess/)
    }.should fail_with("expected no RuntimeError with message matching /ample mess/, got #<RuntimeError: example message>")
  end
end
