module AttributeFu
  # Methods for building forms that contain fields for associated models.
  #
  # Refer to the Conventions section in the README for the various expected defaults.
  #
  module AssociatedFormHelper
    # Works similarly to fields_for, but used for building forms for associated objects.
    # 
    # Automatically names fields to be compatible with the association_attributes= created by attribute_fu.
    #
    # An options hash can be specified to override the default behaviors.
    #
    # Options are:
    # <tt>:javascript</tt>  - Generate id placeholders for use with Prototype's Template class (this is how attribute_fu's add_associated_link works). 
    # <tt>:name</tt>        - Specify the singular name of the association (in singular form), if it differs from the class name of the object.
    #
    # Any other supplied parameters are passed along to fields_for.
    # 
    # Note: It is preferable to call render_associated_form, which will automatically wrap your form partial in a fields_for_associated call.
    #
    def fields_for_associated(associated, *args, &block)
      conf            = args.last.is_a?(Hash) ? args.last : {}
      associated_name = extract_option_or_class_name(conf, :name, associated)
      name            = associated_base_name associated_name
      
      unless associated.new_record?
        name << "[#{associated.new_record? ? 'new' : associated.id}]"
      else
        @new_objects ||= {}
        @new_objects[associated_name] ||= -1 # we want naming to start at 0
        identifier = !conf.nil? && conf[:javascript] ? '#{number}' : @new_objects[associated_name]+=1
        
        name << "[new][#{identifier}]"
      end
      
      @template.fields_for(name, *args.unshift(associated), &block)
    end
    
    # Creates a link for removing an associated element from the form, by removing its containing element from the DOM.
    #
    # Must be called from within an associated form.
    #     
    # An options hash can be specified to override the default behaviors.
    #
    # Options are:
    # * <tt>:selector</tt>  - The CSS selector with which to find the element to remove.
    # * <tt>:function</tt>  - Additional javascript to be executed before the element is removed.
    #
    # Any remaining options are passed along to link_to_function
    #
    def remove_link(name, *args)
      options = args.extract_options!

      css_selector = options.delete(:selector) || ".#{@object.class.name.split("::").last.underscore}"
      function     = options.delete(:function) || ""
      
      function << "$(this).up('#{css_selector}').remove()"
      
      @template.link_to_function(name, function, *args.push(options))
    end
    
    # Creates a link that adds a new associated form to the page using Javascript.
    #
    # Must be called from within an associated form.
    #
    # Must be provided with a new instance of the associated object.
    #
    #   e.g. f.add_associated_link 'Add Task', @project.tasks.build
    #
    # An options hash can be specified to override the default behaviors.
    #
    # Options are:
    # * <tt>:partial</tt>    - specify the name of the partial in which the form is located.
    # * <tt>:container</tt>  - specify the DOM id of the container in which to insert the new element.
    # * <tt>:expression</tt> - specify a javascript expression with which to select the container to insert the new form in to (i.e. $(this).up('.tasks'))
    # * <tt>:name</tt>       - specify an alternate class name for the associated model (underscored)
    #
    # Any additional options are forwarded to link_to_function. See its documentation for available options.
    #
    def add_associated_link(name, object, opts = {})
      associated_name  = extract_option_or_class_name(opts, :name, object)
      variable         = "attribute_fu_#{associated_name}_count"
      
      opts.symbolize_keys!
      partial          = opts.delete(:partial)    || associated_name
      container        = opts.delete(:expression) || "'#{opts.delete(:container) || associated_name.pluralize}'"
      
      form_builder     = self # because the value of self changes in the block
      
      @template.link_to_function(name, opts) do |page|
        page << "if (typeof #{variable} == 'undefined') #{variable} = 0;"
        page << "new Insertion.Bottom(#{container}, new Template("+form_builder.render_associated_form(object, :fields_for => { :javascript => true }, :partial => partial).to_json+").evaluate({'number': --#{variable}}))"
      end
    end
    
    # Renders the form of an associated object, wrapping it in a fields_for_associated call.
    #
    # The associated argument can be either an object, or a collection of objects to be rendered.
    #
    # An options hash can be specified to override the default behaviors.
    # 
    # Options are:
    # * <tt>:new</tt>        - specify a certain number of new elements to be added to the form. Useful for displaying a 
    #   few blank elements at the bottom.
    # * <tt>:name</tt>       - override the name of the association, both for the field names, and the name of the partial
    # * <tt>:partial</tt>    - specify the name of the partial in which the form is located.
    # * <tt>:fields_for</tt> - specify additional options for the fields_for_associated call
    # * <tt>:locals</tt>     - specify additional variables to be passed along to the partial
    # * <tt>:render</tt>     - specify additional options to be passed along to the render :partial call
    #
    def render_associated_form(associated, opts = {})
      associated = associated.is_a?(Array) ? associated : [associated] # preserve association proxy if this is one
      
      opts.symbolize_keys!
      (opts[:new] - associated.select(&:new_record?).length).times { associated.build } if opts[:new]

      unless associated.empty?
        name              = extract_option_or_class_name(opts, :name, associated.first)
        partial           = opts[:partial] || name
        local_assign_name = partial.split('/').last.split('.').first

        associated.map do |element|
          fields_for_associated(element, (opts[:fields_for] || {}).merge(:name => name)) do |f|
            @template.render({:partial => "#{partial}", :locals => {local_assign_name.to_sym => element, :f => f}.merge(opts[:locals] || {})}.merge(opts[:render] || {}))
          end
        end
      end
    end
    
    private
      def associated_base_name(associated_name)
        "#{@object_name}[#{associated_name}_attributes]"
      end
      
      def extract_option_or_class_name(hash, option, object)
        (hash.delete(option) || object.class.name.split('::').last.underscore).to_s
      end
  end
end
