require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "have_text" do
  
  describe "where target is a Regexp" do
    it 'should should match submitted text using a regexp' do
      string = 'foo'
      string.should have_text(/fo*/)
    end
  end
  
  describe "where target is a String" do
    it 'should match submitted text using a string' do
      string = 'foo'
      string.should have_text('foo')
    end
  end
  
end

describe "have_text",
  :type => :controller do
  ['isolation','integration'].each do |mode|
    if mode == 'integration'
      integrate_views
    end

    describe "where target is a response (in #{mode} mode)" do
      controller_name :render_spec

      it "should pass with exactly matching text" do
        post 'text_action'
        response.should have_text("this is the text for this action")
      end

      it "should pass with matching text (using Regexp)" do
        post 'text_action'
        response.should have_text(/is the text/)
      end

      it "should fail with matching text" do
        post 'text_action'
        lambda {
          response.should have_text("this is NOT the text for this action")
        }.should fail_with("expected \"this is NOT the text for this action\", got \"this is the text for this action\"")
      end

      it "should fail when a template is rendered" do
        post 'some_action'
        lambda {
          response.should have_text("this is the text for this action")
        }.should fail_with(/expected \"this is the text for this action\", got .*/)
      end
      
      it "should pass using should_not with incorrect text" do
        post 'text_action'
        response.should_not have_text("the accordian guy")
      end
    end
  end
end

