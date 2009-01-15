require File.dirname(__FILE__) + '/../../../spec_helper'

# assert_select plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org

class AssertSelectController < ActionController::Base

  def response=(content)
    @content = content
  end

  #NOTE - this is commented because response is implemented in lib/spec/rails/context/controller
  # def response(&block)
  #   @update = block
  # end
  # 
  def html()
    render :text=>@content, :layout=>false, :content_type=>Mime::HTML
    @content = nil
  end

  def rjs()
    update = @update
    render :update do |page|
      update.call page
    end
    @update = nil
  end

  def xml()
    render :text=>@content, :layout=>false, :content_type=>Mime::XML
    @content = nil
  end

end

class AssertSelectMailer < ActionMailer::Base

  def test(html)
    recipients "test <test@test.host>"
    from "test@test.host"
    subject "Test e-mail"
    part :content_type=>"text/html", :body=>html
  end

end

module AssertSelectSpecHelpers
  def render_html(html)
    @controller.response = html
    get :html
  end

  def render_rjs(&block)
    clear_response
    @controller.response &block
    get :rjs
  end

  def render_xml(xml)
    @controller.response = xml
    get :xml
  end
  
  def first_non_rspec_line_in_backtrace_of(error)
    rspec_path = File.join('rspec', 'lib', 'spec')
    error.backtrace.reject { |line|
      line =~ /#{rspec_path}/
    }.first
  end

  private
    # necessary for 1.2.1
    def clear_response
      render_html("")
    end
end

unless defined?(SpecFailed)
  SpecFailed = Spec::Expectations::ExpectationNotMetError 
end

describe "should have_tag", :type => :controller do
  include AssertSelectSpecHelpers
  controller_name :assert_select
  integrate_views

  it "should find specific numbers of elements" do
    render_html %Q{<div id="1"></div><div id="2"></div>}
    response.should have_tag( "div" )
    response.should have_tag("div", 2)
    lambda { response.should_not have_tag("div") }.should raise_error(SpecFailed, "should not have tag(\"div\"), but did")

    lambda { response.should have_tag("div", 3) }.should raise_error(SpecFailed)
    lambda { response.should have_tag("p") }.should raise_error(SpecFailed)
  end

  it "should expect to find elements when using true" do
    render_html %Q{<div id="1"></div><div id="2"></div>}
    response.should have_tag( "div", true )
    lambda { response.should have_tag( "p", true )}.should raise_error(SpecFailed)
  end

  it "should expect to not find elements when using false" do
    render_html %Q{<div id="1"></div><div id="2"></div>}
    response.should have_tag( "p", false )
    lambda { response.should have_tag( "div", false )}.should raise_error(SpecFailed)
  end


  it "should match submitted text using text or regexp" do
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    response.should have_tag("div", "foo")
    response.should have_tag("div", /(foo|bar)/)
    response.should have_tag("div", :text=>"foo")
    response.should have_tag("div", :text=>/(foo|bar)/)

    lambda { response.should have_tag("div", "bar") }.should raise_error(SpecFailed)
    lambda { response.should have_tag("div", :text=>"bar") }.should raise_error(SpecFailed)
    lambda { response.should have_tag("p", :text=>"foo") }.should raise_error(SpecFailed)

    lambda { response.should have_tag("div", /foobar/) }.should raise_error(SpecFailed)
    lambda { response.should have_tag("div", :text=>/foobar/) }.should raise_error(SpecFailed)
    lambda { response.should have_tag("p", :text=>/foo/) }.should raise_error(SpecFailed)
  end
  
  it "should use submitted message" do
    render_html %Q{nothing here}
    lambda {
      response.should have_tag("div", {}, "custom message")
    }.should raise_error(SpecFailed, /custom message/)
  end

  it "should match submitted html" do
    render_html %Q{<p>\n<em>"This is <strong>not</strong> a big problem,"</em> he said.\n</p>}
    text = "\"This is not a big problem,\" he said."
    html = "<em>\"This is <strong>not</strong> a big problem,\"</em> he said."
    response.should have_tag("p", text)
    lambda { response.should have_tag("p", html) }.should raise_error(SpecFailed)
    response.should have_tag("p", :html=>html)
    lambda { response.should have_tag("p", :html=>text) }.should raise_error(SpecFailed)

    # # No stripping for pre.
    render_html %Q{<pre>\n<em>"This is <strong>not</strong> a big problem,"</em> he said.\n</pre>}
    text = "\n\"This is not a big problem,\" he said.\n"
    html = "\n<em>\"This is <strong>not</strong> a big problem,\"</em> he said.\n"
    response.should have_tag("pre", text)
    lambda { response.should have_tag("pre", html) }.should raise_error(SpecFailed)
    response.should have_tag("pre", :html=>html)
    lambda { response.should have_tag("pre", :html=>text) }.should raise_error(SpecFailed)
  end

  it "should match number of instances" do
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    response.should have_tag("div", 2)
    lambda { response.should have_tag("div", 3) }.should raise_error(SpecFailed)
    response.should have_tag("div", 1..2)
    lambda { response.should have_tag("div", 3..4) }.should raise_error(SpecFailed)
    response.should have_tag("div", :count=>2)
    lambda { response.should have_tag("div", :count=>3) }.should raise_error(SpecFailed)
    response.should have_tag("div", :minimum=>1)
    response.should have_tag("div", :minimum=>2)
    lambda { response.should have_tag("div", :minimum=>3) }.should raise_error(SpecFailed)
    response.should have_tag("div", :maximum=>2)
    response.should have_tag("div", :maximum=>3)
    lambda { response.should have_tag("div", :maximum=>1) }.should raise_error(SpecFailed)
    response.should have_tag("div", :minimum=>1, :maximum=>2)
    lambda { response.should have_tag("div", :minimum=>3, :maximum=>4) }.should raise_error(SpecFailed)
  end

  it "substitution values" do
    render_html %Q{<div id="1">foo</div><div id="2">foo</div><span id="3"></span>}
    response.should have_tag("div#?", /\d+/) do |elements| #using do/end
      elements.size.should == 2
    end
    response.should have_tag("div#?", /\d+/) { |elements| #using {}
      elements.size.should == 2
    }
    lambda {
      response.should have_tag("div#?", /\d+/) do |elements|
        elements.size.should == 3
      end
    }.should raise_error(SpecFailed, "expected: 3,\n     got: 2 (using ==)")
    
    lambda {
      response.should have_tag("div#?", /\d+/) { |elements|
        elements.size.should == 3
      }
    }.should raise_error(SpecFailed, "expected: 3,\n     got: 2 (using ==)")

    response.should have_tag("div#?", /\d+/) do |elements|
      elements.size.should == 2
      with_tag("#1")
      with_tag("#2")
      without_tag("#3")
    end 
  end
  
  #added for RSpec
  it "nested tags in form" do
    render_html %Q{
      <form action="test">
        <input type="text" name="email">
      </form>
      <form action="other">
        <input type="text" name="other_input">
      </form>
    }
    response.should have_tag("form[action=test]") { |form|
      with_tag("input[type=text][name=email]")
    }
    response.should have_tag("form[action=test]") { |form|
      with_tag("input[type=text][name=email]")
    }
    
    lambda {
      response.should have_tag("form[action=test]") { |form|
        with_tag("input[type=text][name=other_input]")
      }
    }.should raise_error(SpecFailed)
    
    lambda {
      response.should have_tag("form[action=test]") {
        with_tag("input[type=text][name=other_input]")
      }
    }.should raise_error(SpecFailed)
  end
  
  it "should report the correct line number for a nested failed expectation" do
    render_html %Q{
      <form action="test">
        <input type="text" name="email">
      </form>
    }
    begin
      response.should have_tag("form[action=test]") {
        @expected_error_line = __LINE__; should have_tag("input[type=text][name=other_input]")
      }
    rescue => e
      first_non_rspec_line_in_backtrace_of(e).should =~ 
        /#{File.basename(__FILE__)}:#{@expected_error_line}/
    else
      fail
    end
  end

  it "should report the correct line number for a nested raised exception" do
    render_html %Q{
      <form action="test">
        <input type="text" name="email">
      </form>
    }
    begin
      response.should have_tag("form[action=test]") {
        @expected_error_line = __LINE__; raise "Failed!"
      }
    rescue => e
      first_non_rspec_line_in_backtrace_of(e).should =~ 
        /#{File.basename(__FILE__)}:#{@expected_error_line}/
    else
      fail
    end
  end

  it "should report the correct line number for a nested failed test/unit assertion" do
    pending "Doesn't work at the moment. Do we want to support this?" do
      render_html %Q{
        <form action="test">
          <input type="text" name="email">
        </form>
      }
      begin
        response.should have_tag("form[action=test]") {
          @expected_error_line = __LINE__; assert false
        }
      rescue => e
        first_non_rspec_line_in_backtrace_of(e).should =~
          /#{File.basename(__FILE__)}:#{@expected_error_line}/
      else
        fail
      end
    end
  end

  
  it "beatles" do
    unless defined?(BEATLES)
      BEATLES = [
        ["John", "Guitar"],
        ["George", "Guitar"],
        ["Paul", "Bass"],
        ["Ringo", "Drums"]
      ]
    end

    render_html %Q{
      <div id="beatles">
        <div class="beatle">
          <h2>John</h2><p>Guitar</p>
        </div>
        <div class="beatle">
          <h2>George</h2><p>Guitar</p>
        </div>
        <div class="beatle">
          <h2>Paul</h2><p>Bass</p>
        </div>
        <div class="beatle">
          <h2>Ringo</h2><p>Drums</p>
        </div>
      </div>          
    }
    response.should have_tag("div#beatles>div[class=\"beatle\"]", 4)

    response.should have_tag("div#beatles>div.beatle") {
      BEATLES.each { |name, instrument|
        with_tag("div.beatle>h2", name)
        with_tag("div.beatle>p", instrument)
        without_tag("div.beatle>span")
      }
    }
  end

  it "assert_select_text_match" do
    render_html %Q{<div id="1"><span>foo</span></div><div id="2"><span>bar</span></div>}
    response.should have_tag("div") do |divs|
      with_tag("div", "foo")
      with_tag("div", "bar")
      with_tag("div", /\w*/)
      with_tag("div", /\w*/, :count=>2)
      without_tag("div", :text=>"foo", :count=>2)
      with_tag("div", :html=>"<span>bar</span>")
      with_tag("div", :html=>"<span>bar</span>")
      with_tag("div", :html=>/\w*/)
      with_tag("div", :html=>/\w*/, :count=>2)
      without_tag("div", :html=>"<span>foo</span>", :count=>2)
    end
  end


  it "assert_select_from_rjs with one item" do
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>\n<div id=\"2\">foo</div>"
    end
    response.should have_tag("div") { |elements|
      elements.size.should == 2
      with_tag("#1")
      with_tag("#2")
    }
    
    lambda {
      response.should have_tag("div") { |elements|
        elements.size.should == 2
        with_tag("#1")
        with_tag("#3")
      }
    }.should raise_error(SpecFailed)

    lambda {
      response.should have_tag("div") { |elements|
        elements.size.should == 2
        with_tag("#1")
        without_tag("#2")
      }
    }.should raise_error(SpecFailed, "should not have tag(\"#2\"), but did")

    lambda {
      response.should have_tag("div") { |elements|
        elements.size.should == 3
        with_tag("#1")
        with_tag("#2")
      }
    }.should raise_error(SpecFailed)


    response.should have_tag("div#?", /\d+/) { |elements|
      with_tag("#1")
      with_tag("#2")
    }
  end
  
  it "assert_select_from_rjs with multiple items" do
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
    end
    response.should have_tag("div")
    response.should have_tag("div") { |elements|
      elements.size.should == 2
      with_tag("#1")
      with_tag("#2")
    }

    lambda {
      response.should have_tag("div") { |elements|
        with_tag("#3")
      }
    }.should raise_error(SpecFailed)
  end
end

describe "css_select", :type => :controller do
  include AssertSelectSpecHelpers
  controller_name :assert_select
  integrate_views

  it "can select tags from html" do
    render_html %Q{<div id="1"></div><div id="2"></div>}
    css_select("div").size.should == 2
    css_select("p").size.should == 0
  end


  it "can select nested tags from html" do
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
    response.should have_tag("div#?", /\d+/) { |elements|
      css_select(elements[0], "div").should have(1).element
      css_select(elements[1], "div").should have(1).element
    }
    response.should have_tag("div") {
      css_select("div").should have(2).elements
      css_select("div").each { |element|
        # Testing as a group is one thing
        css_select("#1,#2").should have(2).elements
        # Testing individually is another
        css_select("#1").should have(1).element
        css_select("#2").should have(1).element
      }
    }
  end

  it "can select nested tags from rjs (one result)" do
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>\n<div id=\"2\">foo</div>"
    end
    css_select("div").should have(2).elements
    css_select("#1").should have(1).element
    css_select("#2").should have(1).element
  end

  it "can select nested tags from rjs (two results)" do
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
    end
    css_select("div").should have(2).elements
    css_select("#1").should have(1).element
    css_select("#2").should have(1).element
  end
  
end

describe "have_rjs behaviour_type", :type => :controller do
  include AssertSelectSpecHelpers
  controller_name :assert_select
  integrate_views

  before(:each) do
    render_rjs do |page|
      page.replace "test1", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">bar</div><div id=\"3\">none</div>"
      page.insert_html :top, "test3", "<div id=\"4\">loopy</div>"
      page.hide "test4"
      page["test5"].hide
    end
  end
  
  it "should pass if any rjs exists" do
    response.should have_rjs
  end
  
  it "should fail if no rjs exists" do
    render_rjs do |page|
    end
    lambda do
      response.should have_rjs
    end.should raise_error(SpecFailed)
  end
  
  it "should find all rjs from multiple statements" do
    response.should have_rjs do
      with_tag("#1")
      with_tag("#2")
      with_tag("#3")
      # with_tag("#4")
      # with_tag("#5")
    end
  end

  it "should find by id" do
    response.should have_rjs("test1") { |rjs|
      rjs.size.should == 1
      with_tag("div", 1)
      with_tag("div#1", "foo")
    }
    
    lambda do
      response.should have_rjs("test1") { |rjs|
        rjs.size.should == 1
        without_tag("div#1", "foo")
      }
    end.should raise_error(SpecFailed, "should not have tag(\"div#1\", \"foo\"), but did")

    response.should have_rjs("test2") { |rjs|
      rjs.size.should == 2
      with_tag("div", 2)
      with_tag("div#2", "bar")
      with_tag("div#3", "none")
    }
    # response.should have_rjs("test4")
    # response.should have_rjs("test5")
  end
  
  # specify "should find rjs using :hide" do
  #   response.should have_rjs(:hide)
  #   response.should have_rjs(:hide, "test4")
  #   response.should have_rjs(:hide, "test5")
  #   lambda do
  #     response.should have_rjs(:hide, "test3")
  #   end.should raise_error(SpecFailed)
  # end

  it "should find rjs using :replace" do
    response.should have_rjs(:replace) { |rjs|
      with_tag("div", 1)
      with_tag("div#1", "foo")
    }
    response.should have_rjs(:replace, "test1") { |rjs|
      with_tag("div", 1)
      with_tag("div#1", "foo")
    }
    lambda {
      response.should have_rjs(:replace, "test2")
    }.should raise_error(SpecFailed)

    lambda {
      response.should have_rjs(:replace, "test3")
    }.should raise_error(SpecFailed)
  end

  it "should find rjs using :replace_html" do
    response.should have_rjs(:replace_html) { |rjs|
      with_tag("div", 2)
      with_tag("div#2", "bar")
      with_tag("div#3", "none")
    }

    response.should have_rjs(:replace_html, "test2") { |rjs|
      with_tag("div", 2)
      with_tag("div#2", "bar")
      with_tag("div#3", "none")
    }

    lambda {
      response.should have_rjs(:replace_html, "test1")
    }.should raise_error(SpecFailed)

    lambda {
      response.should have_rjs(:replace_html, "test3")
    }.should raise_error(SpecFailed)
  end
    
  it "should find rjs using :insert_html (non-positioned)" do
    response.should have_rjs(:insert_html) { |rjs|
      with_tag("div", 1)
      with_tag("div#4", "loopy")
    }

    response.should have_rjs(:insert_html, "test3") { |rjs|
      with_tag("div", 1)
      with_tag("div#4", "loopy")
    }

    lambda {
      response.should have_rjs(:insert_html, "test1")
    }.should raise_error(SpecFailed)

    lambda {
      response.should have_rjs(:insert_html, "test2")
    }.should raise_error(SpecFailed)
  end

  it "should find rjs using :insert (positioned)" do
    render_rjs do |page|
      page.insert_html :top, "test1", "<div id=\"1\">foo</div>"
      page.insert_html :bottom, "test2", "<div id=\"2\">bar</div>"
      page.insert_html :before, "test3", "<div id=\"3\">none</div>"
      page.insert_html :after, "test4", "<div id=\"4\">loopy</div>"
    end
    response.should have_rjs(:insert, :top) do
      with_tag("div", 1)
      with_tag("#1")
    end
    response.should have_rjs(:insert, :top, "test1") do
      with_tag("div", 1)
      with_tag("#1")
    end
    response.should have_rjs(:insert, :bottom) {|rjs|
      with_tag("div", 1)
      with_tag("#2")
    }
    response.should have_rjs(:insert, :bottom, "test2") {|rjs|
      with_tag("div", 1)
      with_tag("#2")
    }
    response.should have_rjs(:insert, :before) {|rjs|
      with_tag("div", 1)
      with_tag("#3")
    }
    response.should have_rjs(:insert, :before, "test3") {|rjs|
      with_tag("div", 1)
      with_tag("#3")
    }
    response.should have_rjs(:insert, :after) {|rjs|
      with_tag("div", 1)
      with_tag("#4")
    }
    response.should have_rjs(:insert, :after, "test4") {|rjs|
      with_tag("div", 1)
      with_tag("#4")
    }
  end
  
  it "should find rjs using :insert (positioned)" do
    pending("await fix for http://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/982")
    render_rjs do |page|
      page.insert_html :top, "test1", "<div id=\"1\">foo</div>"
      page.insert_html :bottom, "test2", "<div id=\"2\">bar</div>"
    end
    lambda {
      response.should have_rjs(:insert, :top, "test2")
    }.should raise_error(SpecFailed)
  end
end

describe "send_email behaviour_type", :type => :controller do
  include AssertSelectSpecHelpers
  controller_name :assert_select
  integrate_views

  before(:each) do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  after(:each) do
    ActionMailer::Base.deliveries.clear
  end

  it "should fail with nothing sent" do
    response.should_not send_email
    lambda {
      response.should send_email{}
    }.should raise_error(SpecFailed, /No e-mail in delivery list./)
  end
  
  it "should pass otherwise" do
    AssertSelectMailer.deliver_test "<div><p>foo</p><p>bar</p></div>"
    response.should send_email
    lambda {
      response.should_not send_email
    }.should raise_error(SpecFailed)
    response.should send_email{}
    response.should send_email {
      with_tag("div:root") {
        with_tag("p:first-child", "foo")
        with_tag("p:last-child", "bar")
      }
    }
    
    lambda {
      response.should_not send_email
    }.should raise_error(SpecFailed, "should not send email, but did")
  end

end

# describe "An rjs call to :visual_effect, a 'should have_rjs' spec with",
#   :type => :view do
#     
#   before do
#     render 'rjs_spec/visual_effect'
#   end
# 
#   it "should pass with the correct element name" do
#     response.should have_rjs(:effect, :fade, 'mydiv')
#   end
#   
#   it "should fail the wrong element name" do
#     lambda {
#       response.should have_rjs(:effect, :fade, 'wrongname')
#     }.should raise_error(SpecFailed)
#   end
#   
#   it "should fail with the correct element but the wrong command" do
#     lambda {
#       response.should have_rjs(:effect, :puff, 'mydiv')
#     }.should raise_error(SpecFailed)
#   end
#   
# end
#   
# describe "An rjs call to :visual_effect for a toggle, a 'should have_rjs' spec with",
#   :type => :view do
#     
#   before do
#     render 'rjs_spec/visual_toggle_effect'
#   end
#   
#   it "should pass with the correct element name" do
#     response.should have_rjs(:effect, :toggle_blind, 'mydiv')
#   end
#   
#   it "should fail with the wrong element name" do
#     lambda {
#       response.should have_rjs(:effect, :toggle_blind, 'wrongname')
#     }.should raise_error(SpecFailed)
#   end
#   
#   it "should fail the correct element but the wrong command" do
#     lambda {
#       response.should have_rjs(:effect, :puff, 'mydiv')
#     }.should raise_error(SpecFailed)
#   end
#   
# end

describe "string.should have_tag", :type => :helper do
  include AssertSelectSpecHelpers

  it "should find root element" do
    "<p>a paragraph</p>".should have_tag("p", "a paragraph")
  end

  it "should not find non-existent element" do
    lambda do
      "<p>a paragraph</p>".should have_tag("p", "wrong text")
    end.should raise_error(SpecFailed)
  end

  it "should find child element" do
    "<div><p>a paragraph</p></div>".should have_tag("p", "a paragraph")
  end

  it "should find nested element" do
    "<div><p>a paragraph</p></div>".should have_tag("div") do
      with_tag("p", "a paragraph")
    end
  end

  it "should not find wrong nested element" do
    lambda do
      "<div><p>a paragraph</p></div>".should have_tag("div") do
        with_tag("p", "wrong text")
      end
    end.should raise_error(SpecFailed)
  end
end

describe "have_tag", :type => :controller do
  include AssertSelectSpecHelpers
  controller_name :assert_select
  integrate_views

  it "should work exactly the same as assert_select" do
    render_html %Q{
      <div id="wrapper">foo
        <div class="piece">
          <h3>Text</h3>
        </div>
        <div class="piece">
          <h3>Another</h3>
        </div>      
      </div>
    }

    assert_select "#wrapper .piece h3", :text => "Text"
    assert_select "#wrapper .piece h3", :text => "Another"

    response.should have_tag("#wrapper .piece h3", :text => "Text")
    response.should have_tag("#wrapper .piece h3", :text => "Another")
  end
end

describe 'selecting in HTML that contains a mock with null_object' do
  module HTML
    class Document
      def initialize_with_strict_error_checking(text, strict=false, xml=false)
        initialize_without_strict_error_checking(text, true, xml)
      end
      alias_method :initialize_without_strict_error_checking, :initialize
      alias_method :initialize, :initialize_with_strict_error_checking
    end
  end
  
  describe 'modified HTML::Document' do
    it 'should raise error on valid HTML even though false is specified' do
      lambda {HTML::Document.new("<b>#<Spec::Mocks::Mock:0x267b4f0></b>", false, false)}.should raise_error
    end
  end
    
  it 'should not print errors from assert_select' do
    mock = mock("Dog", :null_object => true)
    html = "<b>#{mock.colour}</b>"
    lambda {html.should have_tag('b')}.should_not raise_error
  end
end