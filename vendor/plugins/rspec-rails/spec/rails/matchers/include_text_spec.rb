require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "include_text" do

  describe "where target is a String" do
    it 'should match submitted text using a string' do
      string = 'foo'
      string.should include_text('foo')
    end

    it 'should match if the text is contained' do
      string = 'I am a big piece of text'
      string.should include_text('big piece')
    end

    it 'should not match if text is not contained' do
      string = 'I am a big piece of text'
      string.should_not include_text('corey')
    end
  end

end

describe "include_text", :type => :controller do
  ['isolation','integration'].each do |mode|
    if mode == 'integration'
      integrate_views
    end

    describe "where target is a response (in #{mode} mode)" do
      controller_name :render_spec

      it "should pass with exactly matching text" do
        post 'text_action'
        response.should include_text("this is the text for this action")
      end

      it 'should pass with substring matching text' do
        post 'text_action'
        response.should include_text('text for this')
      end

      it "should fail with matching text" do
        post 'text_action'
        lambda {
          response.should include_text("this is NOT the text for this action")
        }.should fail_with("expected to find \"this is NOT the text for this action\" in \"this is the text for this action\"")
      end

      it "should fail when a template is rendered" do
        post 'some_action'
        failure_message = case mode
        when 'isolation'
          /expected to find \"this is the text for this action\" in \"render_spec\/some_action\"/
        when 'integration'
          /expected to find \"this is the text for this action\" in \"\"/
        end
        lambda {
          response.should include_text("this is the text for this action")
        }.should fail_with(failure_message)
      end

      it "should pass using should_not with incorrect text" do
        post 'text_action'
        response.should_not include_text("the accordian guy")
      end
    end
  end
end

