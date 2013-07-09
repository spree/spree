require 'filters/pretty_urls'

describe PrettyUrls do
  subject { PrettyUrls.new }
  context "correctly translating" do
    it "[Foo Bar](foo_bar) => /foo_bar.html" do
      subject.run("[Foo Bar](foo_bar)").should == "[Foo Bar](foo_bar.html)"
    end

    it "[Foo Bar](foo_bar.html) => /foo_bar.html" do
      subject.run("[Foo Bar](foo_bar.html)").should == "[Foo Bar](foo_bar.html)"
    end

    it "[Foo Bar](foo_bar#buzz) => /foo_bar.html#buzz" do
      subject.run("[Foo Bar](foo_bar#buzz)").should == "[Foo Bar](foo_bar.html#buzz)"
    end

    it "[Foo Bar](foo_bar.html#buzz) => /foo_bar.html#buzz" do
      subject.run("[Foo Bar](foo_bar.html#buzz)").should == "[Foo Bar](foo_bar.html#buzz)"
    end
  end
end