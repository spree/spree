#!/usr/bin/env ruby
require File.dirname(__FILE__) + '/../test_helper'
require 'haml/template'
require 'sass/plugin'
require File.dirname(__FILE__) + '/mocks/article'

require 'action_pack/version'

module Haml::Filters::Test
  include Haml::Filters::Base

  def render(text)
    "TESTING HAHAHAHA!"
  end
end

module Haml::Helpers
  def test_partial(name, locals = {})
    Haml::Engine.new(File.read(File.join(TemplateTest::TEMPLATE_PATH, "_#{name}.haml"))).render(self, locals)
  end
end

class Egocentic
  def method_missing(*args)
    self
  end
end

class DummyController
  attr_accessor :logger
  def initialize
    @logger = Egocentic.new
  end
    
  def self.controller_path
    ''
  end
end

class TemplateTest < Test::Unit::TestCase
  TEMPLATE_PATH = File.join(File.dirname(__FILE__), "templates")
  TEMPLATES = %w{         very_basic        standard    helpers
    whitespace_handling   original_engine   list        helpful
    silent_script         tag_parsing       just_stuff  partials
    filters               nuke_outer_whitespace         nuke_inner_whitespace
    render_layout }
  # partial layouts were introduced in 2.0.0
  TEMPLATES << 'partial_layout' unless ActionPack::VERSION::MAJOR < 2

  def setup
    @base = create_base

    # filters template uses :sass
    Sass::Plugin.options.update(:line_comments => true, :style => :compact)
  end

  def create_base
    vars = { 'article' => Article.new, 'foo' => 'value one' }
    
    unless Haml::Util.has?(:instance_method, ActionView::Base, :finder)
      base = ActionView::Base.new(TEMPLATE_PATH, vars)
    else
      # Rails 2.1.0
      base = ActionView::Base.new([], vars)
      base.finder.append_view_path(TEMPLATE_PATH)
    end
    
    if Haml::Util.has?(:private_method, base, :evaluate_assigns)
      base.send(:evaluate_assigns)
    else
      # Rails 2.2
      base.send(:_evaluate_assigns_and_ivars)
    end

    # This is used by form_for.
    # It's usually provided by ActionController::Base.
    def base.protect_against_forgery?; false; end

    base.controller = DummyController.new
    base
  end

  def render(text)
    Haml::Engine.new(text).to_html(@base)
  end

  def load_result(name)
    @result = ''
    File.new(File.dirname(__FILE__) + "/results/#{name}.xhtml").each_line { |l| @result += l }
    @result
  end

  def assert_renders_correctly(name, &render_method)
    if ActionPack::VERSION::MAJOR < 2 || ActionPack::VERSION::MINOR < 2
      render_method ||= proc { |name| @base.render(name) }
    else
      render_method ||= proc { |name| @base.render(:file => name) }
    end

    load_result(name).split("\n").zip(render_method[name].split("\n")).each_with_index do |pair, line|
      message = "template: #{name}\nline:     #{line}"
      assert_equal(pair.first, pair.last, message)
    end
  rescue ActionView::TemplateError => e
    if e.message =~ /Can't run [\w:]+ filter; required (one of|file) ((?:'\w+'(?: or )?)+)(, but none were found| not found)/
      puts "\nCouldn't require #{$2}; skipping a test."
    else
      raise e
    end
  end

  def test_empty_render_should_remain_empty
    assert_equal('', render(''))
  end

  TEMPLATES.each do |template|
    define_method "test_template_should_render_correctly [template: #{template}] " do
      assert_renders_correctly template
    end
  end

  def test_templates_should_render_correctly_with_render_proc
    assert_renders_correctly("standard") do |name|
      engine = Haml::Engine.new(File.read(File.dirname(__FILE__) + "/templates/#{name}.haml"))
      engine.render_proc(@base).call
    end
  end
  
  def test_templates_should_render_correctly_with_def_method
    assert_renders_correctly("standard") do |name|
      engine = Haml::Engine.new(File.read(File.dirname(__FILE__) + "/templates/#{name}.haml"))
      engine.def_method(@base, "render_standard")
      @base.render_standard
    end
  end

  def test_action_view_templates_render_correctly
    @base.instance_variable_set("@content_for_layout", 'Lorem ipsum dolor sit amet')
    assert_renders_correctly 'content_for_layout'
  end

  def test_instance_variables_should_work_inside_templates
    @base.instance_variable_set("@content_for_layout", 'something')
    assert_equal("<p>something</p>", render("%p= @content_for_layout").chomp)

    @base.instance_eval("@author = 'Hampton Catlin'")
    assert_equal("<div class='author'>Hampton Catlin</div>", render(".author= @author").chomp)

    @base.instance_eval("@author = 'Hampton'")
    assert_equal("Hampton", render("= @author").chomp)

    @base.instance_eval("@author = 'Catlin'")
    assert_equal("Catlin", render("= @author").chomp)
  end

  def test_instance_variables_should_work_inside_attributes
    @base.instance_eval("@author = 'hcatlin'")
    assert_equal("<p class='hcatlin'>foo</p>", render("%p{:class => @author} foo").chomp)
  end

  def test_template_renders_should_eval
    assert_equal("2\n", render("= 1+1"))
  end

  def test_haml_options
    Haml::Template.options = { :suppress_eval => true }
    assert_equal({ :suppress_eval => true }, Haml::Template.options)
    old_base, @base = @base, create_base
    assert_renders_correctly("eval_suppressed")
    @base = old_base
    Haml::Template.options = {}
  end

  def test_exceptions_should_work_correctly
    begin
      render("- raise 'oops!'")
    rescue Exception => e
      assert_equal("oops!", e.message)
      assert_match(/^\(haml\):1/, e.backtrace[0])
    else
      assert false
    end

    template = <<END
%p
  %h1 Hello!
  = "lots of lines"
  = "even more!"
  - raise 'oh no!'
  %p
    this is after the exception
    %strong yes it is!
ho ho ho.
END

    begin
      render(template.chomp)
    rescue Exception => e
      assert_match(/^\(haml\):5/, e.backtrace[0])
    else
      assert false
    end
  end  
end
