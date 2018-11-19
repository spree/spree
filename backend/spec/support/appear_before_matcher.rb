require 'rspec/expectations'

RSpec::Matchers.define :appear_before do |expected|
  match do |actual|
    raise 'Page instance required to use the appear_before matcher' unless page

    page.body.index(actual) <= page.body.index(expected)
  end
end
