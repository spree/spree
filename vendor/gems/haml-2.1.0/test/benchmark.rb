#!/usr/bin/env ruby

times = (ARGV.first || 1000).to_i

if times == 0 # Invalid parameter
  puts <<END
ruby #$0 [times=1000]
  Benchmark Haml against various other templating languages and Sass
  on its own.
END
  exit 1
end

require File.dirname(__FILE__) + '/../lib/haml'
require File.dirname(__FILE__) + '/linked_rails'
%w[sass rubygems erb erubis markaby active_support action_controller
   action_view action_pack haml/template rbench].each {|dep| require(dep)}

def view
  unless Haml::Util.has?(:instance_method, ActionView::Base, :finder)
    return ActionView::Base.new(File.dirname(__FILE__), {})
  end

  # Rails >=2.1.0
  base = ActionView::Base.new
  base.finder.append_view_path(File.dirname(__FILE__))
  base
end

def render(view, file)
  view.render :file => file
end

RBench.run(times) do
  column :haml, :title => "Haml"
  column :haml_ugly, :title => "Haml :ugly"
  column :erb, :title => "ERB"
  column :erubis, :title => "Erubis"

  template_name = 'standard'
  directory = File.dirname(__FILE__) + '/haml'
  haml_template    = File.read("#{directory}/templates/#{template_name}.haml")
  erb_template     = File.read("#{directory}/rhtml/#{template_name}.rhtml")
  markaby_template = File.read("#{directory}/markaby/#{template_name}.mab")

  report "Cached" do
    obj = Object.new

    Haml::Engine.new(haml_template).def_method(obj, :haml)
    Haml::Engine.new(haml_template, :ugly => true).def_method(obj, :haml_ugly)
    Erubis::Eruby.new(erb_template).def_method(obj, :erubis)
    obj.instance_eval("def erb; #{ERB.new(erb_template, nil, '-').src}; end")

    haml      { obj.haml }
    haml_ugly { obj.haml_ugly }
    erb       { obj.erb }
    erubis    { obj.erubis }
  end

  report "ActionView" do
    @base = view

    @base.unmemoize_all
    Haml::Template.options[:ugly] = false
    # To cache the template
    render @base, 'haml/templates/standard'
    render @base, 'haml/rhtml/standard'

    haml { render @base, 'haml/templates/standard' }
    erb  { render @base, 'haml/rhtml/standard' }

    Haml::Template.options[:ugly] = true
    render @base, 'haml/templates/standard_ugly'
    haml_ugly { render @base, 'haml/templates/standard_ugly' }
  end

  report "ActionView with deep partials" do
    @base = view

    @base.unmemoize_all
    Haml::Template.options[:ugly] = false
    # To cache the template
    render @base, 'haml/templates/action_view'
    render @base, 'haml/rhtml/action_view'

    haml { render @base, 'haml/templates/action_view' }
    erb  { render @base, 'haml/rhtml/action_view' }

    Haml::Template.options[:ugly] = true
    render @base, 'haml/templates/action_view_ugly'
    haml_ugly { render @base, 'haml/templates/action_view_ugly' }
  end
end

RBench.run(times) do
  sass_template = File.read("#{File.dirname(__FILE__)}/sass/templates/complex.sass")

  report("Sass") { Sass::Engine.new(sass_template).render }
end
