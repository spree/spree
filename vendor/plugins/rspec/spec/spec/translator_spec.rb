require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'spec/translator'

describe "Translator" do
  before do
    @t = Spec::Translator.new
  end
  
  it "should translate files" do
    from = File.dirname(__FILE__) + '/..'
    to = "#{Dir.tmpdir}/translated_specs"
    @t.translate_dir(from, to)
  end

  it "should translate context_setup  do" do
    @t.translate_line(
      "context_setup  do\n"
    ).should eql(
      "before(:all)  do\n"
    )
  end

  it "should translate context_setup  {foo}" do
    @t.translate_line(
      "context_setup  {foo}\n"
    ).should eql(
      "before(:all)  {foo}\n"
    )
  end
  
  it "should translate context ' to describe '" do
    @t.translate_line(
      "context 'Translator' do\n"
    ).should eql(
      "describe 'Translator' do\n"
    )
  end

  it 'should translate context " to describe "' do
    @t.translate_line(
      'context "Translator"'
    ).should eql(
      'describe "Translator"'
    )
  end

  it 'should translate spaces then context " to describe "' do
    @t.translate_line(
      '  context "Translator"'
    ).should eql(
      '  describe "Translator"'
    )
  end
  
  it "should not translate context=foo" do
    @t.translate_line('  context=foo').should eql('  context=foo')
  end

  it "should not translate context = foo" do
    @t.translate_line('  context = foo').should eql('  context = foo')
  end

  it "should not translate context  =  foo" do
    @t.translate_line('  context  =  foo').should eql('  context  =  foo')
  end
  
  it "should translate should_be_close" do
    @t.translate_line('5.0.should_be_close(5.0, 0.5)').should eql('5.0.should be_close(5.0, 0.5)')
  end

  it "should translate should_not_raise" do
    @t.translate_line('lambda { self.call }.should_not_raise').should eql('lambda { self.call }.should_not raise_error')
  end

  it "should translate should_throw" do
    @t.translate_line('lambda { self.call }.should_throw').should eql('lambda { self.call }.should throw_symbol')
  end

  it "should not translate 0.9 should_not" do
    @t.translate_line('@target.should_not @matcher').should eql('@target.should_not @matcher')
  end

  it "should leave should_not_receive" do
    @t.translate_line('@mock.should_not_receive(:not_expected).with("unexpected text")').should eql('@mock.should_not_receive(:not_expected).with("unexpected text")')
  end

  it "should leave should_receive" do
    @t.translate_line('@mock.should_receive(:not_expected).with("unexpected text")').should eql('@mock.should_receive(:not_expected).with("unexpected text")')
  end
  
  it "should translate multi word predicates" do
    @t.translate_line('foo.should_multi_word_predicate').should eql('foo.should be_multi_word_predicate')
  end

  it "should translate multi word predicates prefixed with be" do
    @t.translate_line('foo.should_be_multi_word_predicate').should eql('foo.should be_multi_word_predicate')
  end

  it "should translate be(expected) to equal(expected)" do
    @t.translate_line('foo.should_be :cool').should eql('foo.should equal :cool')
  end

  it "should translate instance_of" do
    @t.translate_line('5.should_be_an_instance_of(Integer)').should eql('5.should be_an_instance_of(Integer)')
  end

  it "should translate should_be <" do
    @t.translate_line('3.should_be < 4').should eql('3.should be < 4')
  end

  it "should translate should_be <=" do
    @t.translate_line('3.should_be <= 4').should eql('3.should be <= 4')
  end

  it "should translate should_be >=" do
    @t.translate_line('4.should_be >= 3').should eql('4.should be >= 3')
  end

  it "should translate should_be >" do
    @t.translate_line('4.should_be > 3').should eql('4.should be > 3')
  end

  it "should translate should_be_happy" do
    @t.translate_line("4.should_be_happy").should eql("4.should be_happy")
  end
    
  it "should translate custom method taking regexp with parenthesis" do
    @t.translate_line("@browser.should_contain_text(/Sn.rrunger og annet rusk/)").should eql("@browser.should be_contain_text(/Sn.rrunger og annet rusk/)")
  end

  it "should translate custom method taking regexp without parenthesis" do
    @t.translate_line("@browser.should_contain_text /Sn.rrunger og annet rusk/\n").should eql("@browser.should be_contain_text(/Sn.rrunger og annet rusk/)\n")
  end
   
  it "should translate should_not_be_nil" do
    @t.translate_line("foo.should_not_be_nil\n").should eql("foo.should_not be_nil\n")
  end
    
  it "should translate kind of" do
    @t.translate_line('@object.should_be_kind_of(MessageExpectation)').should(
    eql('@object.should be_kind_of(MessageExpectation)'))
  end
  
  it "should translate should_be_true" do
    @t.translate_line("foo.should_be_true\n").should eql("foo.should be_true\n")
  end

  # [#9674] spec_translate incorrectly handling shoud_match, when regexp in a var, in a block
  # http://rubyforge.org/tracker/?func=detail&atid=3149&aid=9674&group_id=797
  it "should translate should_match on a regexp, in a var, in a block" do
    @t.translate_line("collection.each { |c| c.should_match a_regexp_in_a_var }\n").should eql("collection.each { |c| c.should match(a_regexp_in_a_var) }\n")
    @t.translate_line("collection.each{|c| c.should_match a_regexp_in_a_var}\n").should eql("collection.each{|c| c.should match(a_regexp_in_a_var) }\n")
  end
  
  # From Rubinius specs
  it "should translate close_to without parens" do
    @t.translate_line("end.should_be_close 3.14159_26535_89793_23846, TOLERANCE\n").should eql("end.should be_close(3.14159_26535_89793_23846, TOLERANCE)\n")
  end

  # [#9882] 0.9 Beta 1 - translator bugs
  # http://rubyforge.org/tracker/index.php?func=detail&aid=9882&group_id=797&atid=3149
  it "should support symbol arguments" do
    @t.translate_line(
      "lambda { sequence.parse('bar') }.should_throw :ZeroWidthParseSuccess\n"
    ).should eql(
      "lambda { sequence.parse('bar') }.should throw_symbol(:ZeroWidthParseSuccess)\n"
    )
  end

  # [#9882] 0.9 Beta 1 - translator bugs
  # http://rubyforge.org/tracker/index.php?func=detail&aid=9882&group_id=797&atid=3149
  it "should support instance var arguments" do
    @t.translate_line(
      "a.should_eql @local"
    ).should eql(
      "a.should eql(@local)"
    )
  end

  # [#9882] 0.9 Beta 1 - translator bugs
  # http://rubyforge.org/tracker/index.php?func=detail&aid=9882&group_id=797&atid=3149
  it "should support lambdas as expecteds" do
    @t.translate_line(
      "@parslet.should_not_eql lambda { nil }.to_parseable"
    ).should eql(
      "@parslet.should_not eql(lambda { nil }.to_parseable)"
    )
  end
  
  # [#9882] 0.9 Beta 1 - translator bugs
  # http://rubyforge.org/tracker/index.php?func=detail&aid=9882&group_id=797&atid=3149
  it "should support fully qualified names" do
    @t.translate_line(
      "results.should_be_kind_of SimpleASTLanguage::Identifier"
    ).should eql(
      "results.should be_kind_of(SimpleASTLanguage::Identifier)"
    )
  end
    
  # [#9882] 0.9 Beta 1 - translator bugs
  # http://rubyforge.org/tracker/index.php?func=detail&aid=9882&group_id=797&atid=3149
  # it "should leave whitespace between expression and comments" do
  #   @t.translate_line(
  #     "lambda { @instance.foo = foo }.should_raise NoMethodError # no writer defined"
  #   ).should eql(
  #     "lambda { @instance.foo = foo }.should raise_error(NoMethodError) # no writer defined"
  #   )
  # end

  it "should translate redirects" do
    @t.translate_line(
      "controller.should_redirect_to 'http://not_existing_domain_for_novalis.test.host/404.html'"
    ).should eql(
      "controller.should redirect_to('http://not_existing_domain_for_novalis.test.host/404.html')"
    )
  end

  it "should translate :any_args" do
    @t.translate_line(
      "mock.should_receive(:foo).with(:any_args)"
    ).should eql(
      "mock.should_receive(:foo).with(any_args)"
    )
  end

  it "should translate :anything" do
    @t.translate_line(
      "mock.should_receive(:foo).with(:anything)"
    ).should eql(
      "mock.should_receive(:foo).with(anything)"
    )
  end

  it "should translate :boolean" do
    @t.translate_line(
      "mock.should_receive(:foo).with(:boolean)"
    ).should eql(
      "mock.should_receive(:foo).with(boolean)"
    )
  end

  it "should translate :no_args" do
    @t.translate_line(
      "mock.should_receive(:foo).with(:no_args)"
    ).should eql(
      "mock.should_receive(:foo).with(no_args)"
    )
  end

  it "should translate :numeric" do
    @t.translate_line(
      "mock.should_receive(:foo).with(:numeric)"
    ).should eql(
      "mock.should_receive(:foo).with(an_instance_of(Numeric))"
    )
  end

  it "should translate :string" do
    @t.translate_line(
      "mock.should_receive(:foo).with(:string)"
    ).should eql(
      "mock.should_receive(:foo).with(an_instance_of(String))"
    )
  end
end
