#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../test_helper'

class EngineTest < Test::Unit::TestCase
  # A map of erroneous Haml documents to the error messages they should produce.
  # The error messages may be arrays;
  # if so, the second element should be the line number that should be reported for the error.
  # If this isn't provided, the tests will assume the line number should be the last line of the document.
  EXCEPTION_MAP = {
    "!!!\n  a" => "Illegal nesting: nesting within a header command is illegal.",
    "a\n  b" => "Illegal nesting: nesting within plain text is illegal.",
    "/ a\n  b" => "Illegal nesting: nesting within a tag that already has content is illegal.",
    "% a" => 'Invalid tag: "% a".',
    "%p a\n  b" => "Illegal nesting: content can't be both given on the same line as %p and nested within it.",
    "%p=" => "There's no Ruby code for = to evaluate.",
    "%p~" => "There's no Ruby code for ~ to evaluate.",
    "~" => "There's no Ruby code for ~ to evaluate.",
    "=" => "There's no Ruby code for = to evaluate.",
    "%p/\n  a" => "Illegal nesting: nesting within a self-closing tag is illegal.",
    ":a\n  b" => ['Filter "a" is not defined.', 1],
    ":a= b" => 'Invalid filter name ":a= b".',
    "." => "Illegal element: classes and ids must have values.",
    ".#" => "Illegal element: classes and ids must have values.",
    ".{} a" => "Illegal element: classes and ids must have values.",
    ".= a" => "Illegal element: classes and ids must have values.",
    "%p..a" => "Illegal element: classes and ids must have values.",
    "%a/ b" => "Self-closing tags can't have content.",
    "%p{:a => 'b',\n:c => 'd'}/ e" => ["Self-closing tags can't have content.", 2],
    "%p{:a => 'b',\n:c => 'd'}=" => ["There's no Ruby code for = to evaluate.", 2],
    "%p.{:a => 'b',\n:c => 'd'} e" => ["Illegal element: classes and ids must have values.", 1],
    "%p{:a => 'b',\n:c => 'd',\n:e => 'f'}\n%p/ a" => ["Self-closing tags can't have content.", 4],
    "%p{:a => 'b',\n:c => 'd',\n:e => 'f'}\n- raise 'foo'" => ["foo", 4],
    "%p{:a => 'b',\n:c => raise('foo'),\n:e => 'f'}" => ["foo", 2],
    "%p{:a => 'b',\n:c => 'd',\n:e => raise('foo')}" => ["foo", 3],
    " %p foo" => "Indenting at the beginning of the document is illegal.",
    "  %p foo" => "Indenting at the beginning of the document is illegal.",
    "- end" => "You don't need to use \"- end\" in Haml. Use indentation instead:\n- if foo?\n  %strong Foo!\n- else\n  Not foo.",
    " \n\t\n %p foo" => ["Indenting at the beginning of the document is illegal.", 3],
    "\n\n %p foo" => ["Indenting at the beginning of the document is illegal.", 3],
    "%p\n  foo\n foo" => ["Inconsistent indentation: 1 space was used for indentation, but the rest of the document was indented using 2 spaces.", 3],
    "%p\n  foo\n%p\n foo" => ["Inconsistent indentation: 1 space was used for indentation, but the rest of the document was indented using 2 spaces.", 4],
    "%p\n\t\tfoo\n\tfoo" => ["Inconsistent indentation: 1 tab was used for indentation, but the rest of the document was indented using 2 tabs.", 3],
    "%p\n  foo\n   foo" => ["Inconsistent indentation: 3 spaces were used for indentation, but the rest of the document was indented using 2 spaces.", 3],
    "%p\n  foo\n  %p\n   bar" => ["Inconsistent indentation: 3 spaces were used for indentation, but the rest of the document was indented using 2 spaces.", 4],
    "%p\n  :plain\n     bar\n   \t  baz" => ['Inconsistent indentation: "   \t  " was used for indentation, but the rest of the document was indented using 2 spaces.', 4],
    "%p\n  foo\n%p\n    bar" => ["The line was indented 2 levels deeper than the previous line.", 4],
    "%p\n  foo\n  %p\n        bar" => ["The line was indented 3 levels deeper than the previous line.", 4],
    "%p\n \tfoo" => ["Indentation can't use both tabs and spaces.", 2],

    # Regression tests
    "- raise 'foo'\n\n\n\nbar" => ["foo", 1],
    "= 'foo'\n-raise 'foo'" => ["foo", 2],
    "\n\n\n- raise 'foo'" => ["foo", 4],
    "%p foo |\n   bar |\n   baz |\nbop\n- raise 'foo'" => ["foo", 5],
    "foo\n\n\n  bar" => ["Illegal nesting: nesting within plain text is illegal.", 4],
    "%p/\n\n  bar" => ["Illegal nesting: nesting within a self-closing tag is illegal.", 3],
    "%p foo\n\n  bar" => ["Illegal nesting: content can't be both given on the same line as %p and nested within it.", 3],
    "/ foo\n\n  bar" => ["Illegal nesting: nesting within a tag that already has content is illegal.", 3],
    "!!!\n\n  bar" => ["Illegal nesting: nesting within a header command is illegal.", 3],
    "foo\n:ruby\n  1\n  2\n  3\n- raise 'foo'" => ["foo", 6],
  }

  User = Struct.new('User', :id)

  def render(text, options = {}, &block)
    scope  = options.delete(:scope)  || Object.new
    locals = options.delete(:locals) || {}
    engine(text, options).to_html(scope, locals, &block)
  end
  
  def engine(text, options = {})
    unless options[:filename]
      # use caller method name as fake filename. useful for debugging
      i = -1
      caller[i+=1] =~ /`(.+?)'/ until $1 and $1.index('test_') == 0
      options[:filename] = "(#{$1})"
    end
    Haml::Engine.new(text, options)
  end

  def test_empty_render
    assert_equal "", render("")
  end

  def test_flexible_tabulation
    assert_equal("<p>\n  foo\n</p>\n<q>\n  bar\n  <a>\n    baz\n  </a>\n</q>\n",
                 render("%p\n foo\n%q\n bar\n %a\n  baz"))
    assert_equal("<p>\n  foo\n</p>\n<q>\n  bar\n  <a>\n    baz\n  </a>\n</q>\n",
                 render("%p\n\tfoo\n%q\n\tbar\n\t%a\n\t\tbaz"))
    assert_equal("<p>\n      \t \t bar\n   baz\n</p>\n",
                 render("%p\n  :plain\n        \t \t bar\n     baz"))
  end

  def test_empty_render_should_remain_empty
    assert_equal('', render(''))
  end

  def test_attributes_should_render_correctly
    assert_equal("<div class='atlantis' style='ugly'></div>", render(".atlantis{:style => 'ugly'}").chomp)
  end

  def test_ruby_code_should_work_inside_attributes
    author = 'hcatlin'
    assert_equal("<p class='3'>foo</p>", render("%p{:class => 1+2} foo").chomp)
  end

  def test_nil_should_render_empty_tag
    assert_equal("<div class='no_attributes'></div>",
                 render(".no_attributes{:nil => nil}").chomp)
  end

  def test_strings_should_get_stripped_inside_tags
    assert_equal("<div class='stripped'>This should have no spaces in front of it</div>",
                 render(".stripped    This should have no spaces in front of it").chomp)
  end

  def test_one_liner_should_be_one_line
    assert_equal("<p>Hello</p>", render('%p Hello').chomp)
  end

  def test_one_liner_with_newline_shouldnt_be_one_line
    assert_equal("<p>\n  foo\n  bar\n</p>", render('%p= "foo\nbar"').chomp)
  end

  def test_multi_render
    engine = engine("%strong Hi there!")
    assert_equal("<strong>Hi there!</strong>\n", engine.to_html)
    assert_equal("<strong>Hi there!</strong>\n", engine.to_html)
    assert_equal("<strong>Hi there!</strong>\n", engine.to_html)
  end

  def test_double_equals
    assert_equal("<p>Hello World</p>\n", render('%p== Hello #{who}', :locals => {:who => 'World'}))
    assert_equal("<p>\n  Hello World\n</p>\n", render("%p\n  == Hello \#{who}", :locals => {:who => 'World'}))
  end

  def test_double_equals_in_the_middle_of_a_string
    assert_equal("\"title 'Title'. \"\n",
                 render("== \"title '\#{\"Title\"}'. \""))
  end

  def test_nil_tag_value_should_render_as_empty
    assert_equal("<p></p>\n", render("%p= nil"))
  end

  def test_tag_with_failed_if_should_render_as_empty
    assert_equal("<p></p>\n", render("%p= 'Hello' if false"))
  end

  def test_static_attributes_with_empty_attr
    assert_equal("<img alt='' src='/foo.png' />\n", render("%img{:src => '/foo.png', :alt => ''}"))
  end

  def test_dynamic_attributes_with_empty_attr
    assert_equal("<img alt='' src='/foo.png' />\n", render("%img{:width => nil, :src => '/foo.png', :alt => String.new}"))
  end

  def test_attribute_hash_with_newlines
    assert_equal("<p a='b' c='d'>foop</p>\n", render("%p{:a => 'b',\n   :c => 'd'} foop"))
    assert_equal("<p a='b' c='d'>\n  foop\n</p>\n", render("%p{:a => 'b',\n   :c => 'd'}\n  foop"))
    assert_equal("<p a='b' c='d' />\n", render("%p{:a => 'b',\n   :c => 'd'}/"))
    assert_equal("<p a='b' c='d' e='f'></p>\n", render("%p{:a => 'b',\n   :c => 'd',\n   :e => 'f'}"))
  end

  def test_attr_hashes_not_modified
    hash = {:color => 'red'}
    assert_equal(<<HTML, render(<<HAML, :locals => {:hash => hash}))
<div color='red'></div>
<div class='special' color='red'></div>
<div color='red'></div>
HTML
%div{hash}
.special{hash}
%div{hash}
HAML
    assert_equal(hash, {:color => 'red'})
  end

  def test_end_of_file_multiline
    assert_equal("<p>0</p>\n<p>1</p>\n<p>2</p>\n", render("- for i in (0...3)\n  %p= |\n   i |"))
  end

  def test_cr_newline
    assert_equal("<p>foo</p>\n<p>bar</p>\n<p>baz</p>\n<p>boom</p>\n", render("%p foo\r%p bar\r\n%p baz\n\r%p boom"))
  end

  def test_textareas
    assert_equal("<textarea>Foo&#x000A;  bar&#x000A;   baz</textarea>\n",
                 render('%textarea= "Foo\n  bar\n   baz"'))

    assert_equal("<pre>Foo&#x000A;  bar&#x000A;   baz</pre>\n",
                 render('%pre= "Foo\n  bar\n   baz"'))

    assert_equal("<textarea>#{'a' * 100}</textarea>\n",
                 render("%textarea #{'a' * 100}"))

    assert_equal("<p>\n  <textarea>Foo\n  Bar\n  Baz</textarea>\n</p>\n", render(<<SOURCE))
%p
  %textarea
    Foo
    Bar
    Baz
SOURCE
  end

  def test_boolean_attributes
    assert_equal("<p bar baz='true' foo='bar'></p>\n",
                 render("%p{:foo => 'bar', :bar => true, :baz => 'true'}", :format => :html4))
    assert_equal("<p bar='bar' baz='true' foo='bar'></p>\n",
                 render("%p{:foo => 'bar', :bar => true, :baz => 'true'}", :format => :xhtml))

    assert_equal("<p baz='false' foo='bar'></p>\n",
                 render("%p{:foo => 'bar', :bar => false, :baz => 'false'}", :format => :html4))
    assert_equal("<p baz='false' foo='bar'></p>\n",
                 render("%p{:foo => 'bar', :bar => false, :baz => 'false'}", :format => :xhtml))
  end

  def test_both_whitespace_nukes_work_together
    assert_equal(<<RESULT, render(<<SOURCE))
<p><q>Foo
  Bar</q></p>
RESULT
%p
  %q><= "Foo\\nBar"
SOURCE
  end

  # Regression tests

  def test_whitespace_nuke_with_both_newlines
    assert_equal("<p>foo</p>\n", render('%p<= "\nfoo\n"'))
    assert_equal(<<HTML, render(<<HAML))
<p>
  <p>foo</p>
</p>
HTML
%p
  %p<= "\\nfoo\\n"
HAML
  end

  def test_both_case_indentation_work_with_deeply_nested_code
    result = <<RESULT
<h2>
  other
</h2>
RESULT
    assert_equal(result, render(<<HAML))
- case 'other'
- when 'test'
  %h2
    hi
- when 'other'
  %h2
    other
HAML
    assert_equal(result, render(<<HAML))
- case 'other'
  - when 'test'
    %h2
      hi
  - when 'other'
    %h2
      other
HAML
  end

  def test_equals_block_with_ugly
    assert_equal("foo\n", render(<<HAML, :ugly => true))
= capture_haml do
  foo
HAML
  end

  def test_plain_equals_with_ugly
    assert_equal("foo\nbar\n", render(<<HAML, :ugly => true))
= "foo"
bar
HAML
  end

  def test_inline_if
    assert_equal(<<HTML, render(<<HAML))
<p>One</p>
<p></p>
<p>Three</p>
HTML
- for name in ["One", "Two", "Three"]
  %p= name unless name == "Two"
HAML
  end

  # HTML escaping tests

  def test_ampersand_equals_should_escape
    assert_equal("<p>\n  foo &amp; bar\n</p>\n", render("%p\n  &= 'foo & bar'", :escape_html => false))
  end

  def test_ampersand_equals_inline_should_escape
    assert_equal("<p>foo &amp; bar</p>\n", render("%p&= 'foo & bar'", :escape_html => false))
  end

  def test_ampersand_equals_should_escape_before_preserve
    assert_equal("<textarea>foo&#x000A;bar</textarea>\n", render('%textarea&= "foo\nbar"', :escape_html => false))
  end

  def test_bang_equals_should_not_escape
    assert_equal("<p>\n  foo & bar\n</p>\n", render("%p\n  != 'foo & bar'", :escape_html => true))
  end

  def test_bang_equals_inline_should_not_escape
    assert_equal("<p>foo & bar</p>\n", render("%p!= 'foo & bar'", :escape_html => true))
  end
  
  def test_static_attributes_should_be_escaped
    assert_equal("<img class='atlantis' style='ugly&amp;stupid' />\n",
                 render("%img.atlantis{:style => 'ugly&stupid'}"))
    assert_equal("<div class='atlantis' style='ugly&amp;stupid'>foo</div>\n",
                 render(".atlantis{:style => 'ugly&stupid'} foo"))
    assert_equal("<p class='atlantis' style='ugly&amp;stupid'>foo</p>\n",
                render("%p.atlantis{:style => 'ugly&stupid'}= 'foo'"))
    assert_equal("<p class='atlantis' style='ugly&#x000A;stupid'></p>\n",
                render("%p.atlantis{:style => \"ugly\\nstupid\"}"))
  end

  def test_dynamic_attributes_should_be_escaped
    assert_equal("<img alt='' src='&amp;foo.png' />\n",
                 render("%img{:width => nil, :src => '&foo.png', :alt => String.new}"))
    assert_equal("<p alt='' src='&amp;foo.png'>foo</p>\n",
                 render("%p{:width => nil, :src => '&foo.png', :alt => String.new} foo"))
    assert_equal("<div alt='' src='&amp;foo.png'>foo</div>\n",
                 render("%div{:width => nil, :src => '&foo.png', :alt => String.new}= 'foo'"))
    assert_equal("<img alt='' src='foo&#x000A;.png' />\n",
                 render("%img{:width => nil, :src => \"foo\\n.png\", :alt => String.new}"))
  end

  def test_string_double_equals_should_be_esaped
    assert_equal("<p>4&amp;3</p>\n", render("%p== \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>4&3</p>\n", render("%p== \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_escaped_inline_string_double_equals
    assert_equal("<p>4&amp;3</p>\n", render("%p&== \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>4&amp;3</p>\n", render("%p&== \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_unescaped_inline_string_double_equals
    assert_equal("<p>4&3</p>\n", render("%p!== \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>4&3</p>\n", render("%p!== \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_escaped_string_double_equals
    assert_equal("<p>\n  4&amp;3\n</p>\n", render("%p\n  &== \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>\n  4&amp;3\n</p>\n", render("%p\n  &== \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_unescaped_string_double_equals
    assert_equal("<p>\n  4&3\n</p>\n", render("%p\n  !== \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>\n  4&3\n</p>\n", render("%p\n  !== \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_string_interpolation_should_be_esaped
    assert_equal("<p>4&amp;3</p>\n", render("%p \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>4&3</p>\n", render("%p \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_escaped_inline_string_interpolation
    assert_equal("<p>4&amp;3</p>\n", render("%p& \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>4&amp;3</p>\n", render("%p& \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_unescaped_inline_string_interpolation
    assert_equal("<p>4&3</p>\n", render("%p! \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>4&3</p>\n", render("%p! \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_escaped_string_interpolation
    assert_equal("<p>\n  4&amp;3\n</p>\n", render("%p\n  & \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>\n  4&amp;3\n</p>\n", render("%p\n  & \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_unescaped_string_interpolation
    assert_equal("<p>\n  4&3\n</p>\n", render("%p\n  ! \#{2+2}&\#{2+1}", :escape_html => true))
    assert_equal("<p>\n  4&3\n</p>\n", render("%p\n  ! \#{2+2}&\#{2+1}", :escape_html => false))
  end

  def test_scripts_should_respect_escape_html_option
    assert_equal("<p>\n  foo &amp; bar\n</p>\n", render("%p\n  = 'foo & bar'", :escape_html => true))
    assert_equal("<p>\n  foo & bar\n</p>\n", render("%p\n  = 'foo & bar'", :escape_html => false))
  end

  def test_inline_scripts_should_respect_escape_html_option
    assert_equal("<p>foo &amp; bar</p>\n", render("%p= 'foo & bar'", :escape_html => true))
    assert_equal("<p>foo & bar</p>\n", render("%p= 'foo & bar'", :escape_html => false))
  end

  def test_script_ending_in_comment_should_render_when_html_is_escaped
    assert_equal("foo&amp;bar\n", render("= 'foo&bar' #comment", :escape_html => true))
  end

  def test_script_with_if_shouldnt_output
    assert_equal(<<HTML, render(<<HAML))
<p>foo</p>
<p></p>
HTML
%p= "foo"
%p= "bar" if false
HAML
  end

  # Options tests

  def test_filename_and_line
    begin
      render("\n\n = abc", :filename => 'test', :line => 2)
    rescue Exception => e
      assert_kind_of Haml::SyntaxError, e
      assert_match(/test:4/, e.backtrace.first)
    end

    begin
      render("\n\n= 123\n\n= nil[]", :filename => 'test', :line => 2)
    rescue Exception => e
      assert_kind_of NoMethodError, e
      assert_match(/test:6/, e.backtrace.first)
    end
  end

  def test_stop_eval
    assert_equal("", render("= 'Hello'", :suppress_eval => true))
    assert_equal("", render("- haml_concat 'foo'", :suppress_eval => true))
    assert_equal("<div id='foo' yes='no' />\n", render("#foo{:yes => 'no'}/", :suppress_eval => true))
    assert_equal("<div id='foo' />\n", render("#foo{:yes => 'no', :call => a_function() }/", :suppress_eval => true))
    assert_equal("<div />\n", render("%div[1]/", :suppress_eval => true))
    assert_equal("", render(":ruby\n  Kernel.puts 'hello'", :suppress_eval => true))
  end

  def test_doctypes
    assert_equal('<!DOCTYPE html>',
      render('!!!', :format => :html5).strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
      render('!!! strict').strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">',
      render('!!! frameset').strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">',
      render('!!! mobile').strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">',
      render('!!! basic').strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
      render('!!! transitional').strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
      render('!!!').strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">',
      render('!!! strict', :format => :html4).strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">',
      render('!!! frameset', :format => :html4).strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">',
      render('!!! transitional', :format => :html4).strip)
    assert_equal('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">',
      render('!!!', :format => :html4).strip)
  end

  def test_attr_wrapper
    assert_equal("<p strange=*attrs*></p>\n", render("%p{ :strange => 'attrs'}", :attr_wrapper => '*'))
    assert_equal("<p escaped='quo\"te'></p>\n", render("%p{ :escaped => 'quo\"te'}", :attr_wrapper => '"'))
    assert_equal("<p escaped=\"quo'te\"></p>\n", render("%p{ :escaped => 'quo\\'te'}", :attr_wrapper => '"'))
    assert_equal("<p escaped=\"q'uo&quot;te\"></p>\n", render("%p{ :escaped => 'q\\'uo\"te'}", :attr_wrapper => '"'))
    assert_equal("<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n", render("!!! XML", :attr_wrapper => '"'))
  end

  def test_attrs_parsed_correctly
    assert_equal("<p boom=>biddly='bar =&gt; baz'></p>\n", render("%p{'boom=>biddly' => 'bar => baz'}"))
    assert_equal("<p foo,bar='baz, qux'></p>\n", render("%p{'foo,bar' => 'baz, qux'}"))
    assert_equal("<p escaped='quo&#x000A;te'></p>\n", render("%p{ :escaped => \"quo\\nte\"}"))
    assert_equal("<p escaped='quo4te'></p>\n", render("%p{ :escaped => \"quo\#{2 + 2}te\"}"))
  end
  
  def test_correct_parsing_with_brackets
    assert_equal("<p class='foo'>{tada} foo</p>\n", render("%p{:class => 'foo'} {tada} foo"))
    assert_equal("<p class='foo'>deep {nested { things }}</p>\n", render("%p{:class => 'foo'} deep {nested { things }}"))
    assert_equal("<p class='bar foo'>{a { d</p>\n", render("%p{{:class => 'foo'}, :class => 'bar'} {a { d"))
    assert_equal("<p foo='bar'>a}</p>\n", render("%p{:foo => 'bar'} a}"))
    
    foo = []
    foo[0] = Struct.new('Foo', :id).new
    assert_equal("<p class='struct_foo' id='struct_foo_new'>New User]</p>\n",
                 render("%p[foo[0]] New User]", :locals => {:foo => foo}))
    assert_equal("<p class='prefix_struct_foo' id='prefix_struct_foo_new'>New User]</p>\n",
                 render("%p[foo[0], :prefix] New User]", :locals => {:foo => foo}))

    foo[0].id = 1
    assert_equal("<p class='struct_foo' id='struct_foo_1'>New User]</p>\n",
                 render("%p[foo[0]] New User]", :locals => {:foo => foo}))
    assert_equal("<p class='prefix_struct_foo' id='prefix_struct_foo_1'>New User]</p>\n",
                 render("%p[foo[0], :prefix] New User]", :locals => {:foo => foo}))
  end
  
  def test_empty_attrs
    assert_equal("<p attr=''>empty</p>\n", render("%p{ :attr => '' } empty"))
    assert_equal("<p attr=''>empty</p>\n", render("%p{ :attr => x } empty", :locals => {:x => ''}))
  end
  
  def test_nil_attrs
    assert_equal("<p>nil</p>\n", render("%p{ :attr => nil } nil"))
    assert_equal("<p>nil</p>\n", render("%p{ :attr => x } nil", :locals => {:x => nil}))
  end

  def test_nil_id_with_syntactic_id
    assert_equal("<p id='foo'>nil</p>\n", render("%p#foo{:id => nil} nil"))
    assert_equal("<p id='foo_bar'>nil</p>\n", render("%p#foo{{:id => 'bar'}, :id => nil} nil"))
    assert_equal("<p id='foo_bar'>nil</p>\n", render("%p#foo{{:id => nil}, :id => 'bar'} nil"))
  end

  def test_nil_class_with_syntactic_class
    assert_equal("<p class='foo'>nil</p>\n", render("%p.foo{:class => nil} nil"))
    assert_equal("<p class='bar foo'>nil</p>\n", render("%p.bar.foo{:class => nil} nil"))
    assert_equal("<p class='bar foo'>nil</p>\n", render("%p.foo{{:class => 'bar'}, :class => nil} nil"))
    assert_equal("<p class='bar foo'>nil</p>\n", render("%p.foo{{:class => nil}, :class => 'bar'} nil"))
  end

  def test_locals
    assert_equal("<p>Paragraph!</p>\n", render("%p= text", :locals => { :text => "Paragraph!" }))
  end

  def test_dynamic_attrs_shouldnt_register_as_literal_values
    assert_equal("<p a='b2c'></p>\n", render('%p{:a => "b#{1 + 1}c"}'))
    assert_equal("<p a='b2c'></p>\n", render("%p{:a => 'b' + (1 + 1).to_s + 'c'}"))
  end

  def test_dynamic_attrs_with_self_closed_tag
    assert_equal("<a b='2' />\nc\n", render("%a{'b' => 1 + 1}/\n= 'c'\n"))
  end

  def test_exceptions
    EXCEPTION_MAP.each do |key, value|
      begin
        render(key, :filename => "(exception test for #{key.inspect})")
      rescue Exception => err
        value = [value] unless value.is_a?(Array)
        expected_message, line_no = value
        line_no ||= key.split("\n").length
        line_reported = err.backtrace[0].gsub(/\(.+\):/, '').to_i

        assert_equal(expected_message, err.message, "Line: #{key}")
        assert_equal(line_no, line_reported, "Line: #{key}")
      else
        assert(false, "Exception not raised for\n#{key}")
      end
    end
  end

  def test_exception_line
    render("a\nb\n!!!\n  c\nd")
  rescue Haml::SyntaxError => e
    assert_equal("(test_exception_line):4", e.backtrace[0])
  else
    assert(false, '"a\nb\n!!!\n  c\nd" doesn\'t produce an exception')
  end

  def test_exception
    render("%p\n  hi\n  %a= undefined\n= 12")
  rescue Exception => e
    assert_match("(test_exception):3", e.backtrace[0])
  else
    # Test failed... should have raised an exception
    assert(false)
  end

  def test_compile_error
    render("a\nb\n- fee)\nc")
  rescue Exception => e
    assert_match(/\(test_compile_error\):3: syntax error/i, e.message)
  else
    assert(false,
           '"a\nb\n- fee)\nc" doesn\'t produce an exception!')
  end

  def test_unbalanced_brackets
    render('foo #{1 + 5} foo #{6 + 7 bar #{8 + 9}')
  rescue Haml::SyntaxError => e
    assert_equal("Unbalanced brackets.", e.message)
  end

  def test_balanced_conditional_comments
    assert_equal("<!--[if !(IE 6)|(IE 7)]> Bracket: ] <![endif]-->\n",
                 render("/[if !(IE 6)|(IE 7)] Bracket: ]"))
  end

  def test_empty_filter
    assert_equal(<<END, render(':javascript'))
<script type='text/javascript'>
  //<![CDATA[
    
  //]]>
</script>
END
  end

  def test_ugly_filter
    assert_equal(<<END, render(":sass\n  #foo\n    bar: baz", :ugly => true))
#foo {
  bar: baz; }
END
  end

  def test_local_assigns_dont_modify_class
    assert_equal("bar\n", render("= foo", :locals => {:foo => 'bar'}))
    assert_equal(nil, defined?(foo))
  end

  def test_object_ref_with_nil_id
    user = User.new
    assert_equal("<p class='struct_user' id='struct_user_new'>New User</p>\n",
                 render("%p[user] New User", :locals => {:user => user}))
  end

  def test_object_ref_before_attrs
    user = User.new 42
    assert_equal("<p class='struct_user' id='struct_user_42' style='width: 100px;'>New User</p>\n",
                 render("%p[user]{:style => 'width: 100px;'} New User", :locals => {:user => user}))
  end

  def test_non_literal_attributes
    assert_equal("<p a1='foo' a2='bar' a3='baz' />\n",
                 render("%p{a2, a1, :a3 => 'baz'}/",
                        :locals => {:a1 => {:a1 => 'foo'}, :a2 => {:a2 => 'bar'}}))
  end

  def test_render_should_accept_a_binding_as_scope
    string = "This is a string!"
    string.instance_variable_set("@var", "Instance variable")
    b = string.instance_eval do
      var = "Local variable"
      binding
    end

    assert_equal("<p>THIS IS A STRING!</p>\n<p>Instance variable</p>\n<p>Local variable</p>\n",
                 render("%p= upcase\n%p= @var\n%p= var", :scope => b))
  end

  def test_yield_should_work_with_binding
    assert_equal("12\nFOO\n", render("= yield\n= upcase", :scope => "foo".instance_eval{binding}) { 12 })
  end

  def test_yield_should_work_with_def_method
    s = "foo"
    engine("= yield\n= upcase").def_method(s, :render)
    assert_equal("12\nFOO\n", s.render { 12 })
  end

  def test_def_method_with_module
    engine("= yield\n= upcase").def_method(String, :render_haml)
    assert_equal("12\nFOO\n", "foo".render_haml { 12 })
  end

  def test_def_method_locals
    obj = Object.new
    engine("%p= foo\n.bar{:baz => baz}= boom").def_method(obj, :render, :foo, :baz, :boom)
    assert_equal("<p>1</p>\n<div baz='2' class='bar'>3</div>\n", obj.render(:foo => 1, :baz => 2, :boom => 3))
  end

  def test_render_proc_locals
    proc = engine("%p= foo\n.bar{:baz => baz}= boom").render_proc(Object.new, :foo, :baz, :boom)
    assert_equal("<p>1</p>\n<div baz='2' class='bar'>3</div>\n", proc[:foo => 1, :baz => 2, :boom => 3])
  end

  def test_render_proc_with_binding
    assert_equal("FOO\n", engine("= upcase").render_proc("foo".instance_eval{binding}).call)
  end

  def test_ugly_true
    assert_equal("<div id='outer'>\n<div id='inner'>\n<p>hello world</p>\n</div>\n</div>\n",
                 render("#outer\n  #inner\n    %p hello world", :ugly => true))

    assert_equal("<p>#{'s' * 75}</p>\n",
                 render("%p #{'s' * 75}", :ugly => true))

    assert_equal("<p>#{'s' * 75}</p>\n",
                 render("%p= 's' * 75", :ugly => true))
  end

  def test_auto_preserve_unless_ugly
    assert_equal("<pre>foo&#x000A;bar</pre>\n", render('%pre="foo\nbar"'))
    assert_equal("<pre>foo\nbar</pre>\n", render("%pre\n  foo\n  bar"))
    assert_equal("<pre>foo\nbar</pre>\n", render('%pre="foo\nbar"', :ugly => true))
    assert_equal("<pre>foo\nbar</pre>\n", render("%pre\n  foo\n  bar", :ugly => true))
  end

  def test_xhtml_output_option
    assert_equal "<p>\n  <br />\n</p>\n", render("%p\n  %br", :format => :xhtml)
    assert_equal "<a />\n", render("%a/", :format => :xhtml)
  end

  def test_arbitrary_output_option
    assert_raise(Haml::Error, "Invalid output format :html1") { engine("%br", :format => :html1) }
  end

  # HTML 4.0

  def test_html_has_no_self_closing_tags
    assert_equal "<p>\n  <br>\n</p>\n", render("%p\n  %br", :format => :html4)
    assert_equal "<br>\n", render("%br/", :format => :html4)
  end

  def test_html_renders_empty_node_with_closing_tag
    assert_equal "<div class='foo'></div>\n", render(".foo", :format => :html4)
  end

  def test_html_doesnt_add_slash_to_self_closing_tags
    assert_equal "<a>\n", render("%a/", :format => :html4)
    assert_equal "<a foo='2'>\n", render("%a{:foo => 1 + 1}/", :format => :html4)
    assert_equal "<meta>\n", render("%meta", :format => :html4)
    assert_equal "<meta foo='2'>\n", render("%meta{:foo => 1 + 1}", :format => :html4)
  end

  def test_html_ignores_xml_prolog_declaration
    assert_equal "", render('!!! XML', :format => :html4)
  end

  def test_html_has_different_doctype
    assert_equal %{<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">\n},
    render('!!!', :format => :html4)
  end

  # because anything before the doctype triggers quirks mode in IE
  def test_xml_prolog_and_doctype_dont_result_in_a_leading_whitespace_in_html
    assert_no_match(/^\s+/, render("!!! xml\n!!!", :format => :html4))
  end

  # HTML5
  def test_html5_doctype
    assert_equal %{<!DOCTYPE html>\n}, render('!!!', :format => :html5)
  end
end
