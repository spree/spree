# This file makes Haml work with Rails
# by monkeypatching the core template-compilation methods.
# This is necessary for versions <= 2.0.1 because the template handler API
# wasn't sufficiently powerful to deal with caching and so forth.

# This module refers to the ActionView module that's part of Ruby on Rails.
# Haml can be used as an alternate templating engine for it,
# and includes several modifications to make it more Haml-friendly.
# The documentation can be found
# here[http://rubyonrails.org/api/classes/ActionView/Base.html].
module ActionView
  class Base # :nodoc:
    def delegate_template_exists_with_haml(template_path)
      template_exists?(template_path, :haml) && [:haml]
    end
    alias_method :delegate_template_exists_without_haml, :delegate_template_exists?
    alias_method :delegate_template_exists?, :delegate_template_exists_with_haml

    def compile_template_with_haml(extension, template, file_name, local_assigns)
      return compile_haml(template, file_name, local_assigns) if extension.to_s == "haml"
      compile_template_without_haml(extension, template, file_name, local_assigns)
    end
    alias_method :compile_template_without_haml, :compile_template
    alias_method :compile_template, :compile_template_with_haml

    def compile_haml(template, file_name, local_assigns)
      render_symbol = assign_method_name(:haml, template, file_name)
      locals = local_assigns.keys

      @@template_args[render_symbol] ||= {}
      locals_keys = @@template_args[render_symbol].keys | locals
      @@template_args[render_symbol] = Haml::Util.to_hash(locals_keys.map {|k| [k, true]})

      options = Haml::Template.options.dup
      options[:filename] = file_name || 'compiled-template'

      begin
        Haml::Engine.new(template, options).def_method(CompiledTemplates, render_symbol, *locals_keys)
      rescue Exception => e
        if logger
          logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
          logger.debug "Backtrace: #{e.backtrace.join("\n")}"
        end

        base_path = if defined?(extract_base_path_from)
                      # Rails 2.0.x
                      extract_base_path_from(file_name) || view_paths.first
                    else
                      # Rails <=1.2.6
                      @base_path
                    end
        raise ActionView::TemplateError.new(base_path, file_name || template, @assigns, template, e)
      end

      @@compile_time[render_symbol] = Time.now
    end
  end
end
