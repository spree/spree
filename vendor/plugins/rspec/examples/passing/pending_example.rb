require File.dirname(__FILE__) + '/spec_helper'

describe "pending example (using pending method)" do
  it %Q|should be reported as "PENDING: for some reason"| do
    pending("for some reason")
  end
end

describe "pending example (with no block)" do
  it %Q|should be reported as "PENDING: Not Yet Implemented"|
end

describe "pending example (with block for pending)" do
  it %Q|should have a failing block, passed to pending, reported as "PENDING: for some reason"| do
    pending("for some reason") do
      raise "some reason"
    end
  end
end

