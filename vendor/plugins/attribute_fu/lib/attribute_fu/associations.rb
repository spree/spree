module AttributeFu
  module Associations #:nodoc:
    
    def self.included(base) #:nodoc:
      base.class_eval do
        extend ClassMethods
        class << self; alias_method_chain :has_many, :association_option; end
        
        class_inheritable_accessor  :managed_association_attributes
        write_inheritable_attribute :managed_association_attributes, {}
        
        after_update :save_managed_associations
      end
    end
    
    def method_missing(method_name, *args) #:nodoc:
      if method_name.to_s =~ /.+?\_attributes=/
        association_name = method_name.to_s.gsub '_attributes=', ''
        association      = managed_association_attributes.keys.detect { |element| element == association_name.to_sym } || managed_association_attributes.keys.detect { |element| element == association_name.pluralize.to_sym }
        
        unless association.nil?
          has_many_attributes association, args.first
          
          return
        end
      end
      
      super
    end
    
    private
      def has_many_attributes(association_id, attributes) #:nodoc:
        association = send(association_id)
        attributes = {} unless attributes.is_a? Hash

        attributes.symbolize_keys!
        
        if attributes.has_key?(:new)
          new_attrs = attributes.delete(:new)
          new_attrs = new_attrs.sort do |a,b|
            value = lambda { |i| i < 0 ? i.abs + new_attrs.length : i }
            
            value.call(a.first.to_i) <=> value.call(b.first.to_i)
          end
          new_attrs.each { |i, new_attrs| association.build new_attrs } 
        end
        
        attributes.stringify_keys!        
        instance_variable_set removal_variable_name(association_id), association.reject { |object| object.new_record? || attributes.has_key?(object.id.to_s) }.map(&:id)
        attributes.each do |id, object_attrs|
          object = association.detect { |associated| associated.id.to_s == id }
          object.attributes = object_attrs unless object.nil?
        end
        
        # discard blank attributes if discard_if proc exists
        unless (discard = managed_association_attributes[association_id][:discard_if]).nil?
          association.reject! { |object| object.new_record? && discard.call(object) }
          association.delete(*association.select { |object| discard.call(object) })
        end
      end
      
      def save_managed_associations #:nodoc:
        if managed_association_attributes != nil
          managed_association_attributes.keys.each do |association_id|
            if send(association_id).loaded? # don't save what we haven't even loaded
              association = send(association_id)
              association.each(&:save)

              unless (objects_to_remove = instance_variable_get removal_variable_name(association_id)).nil?
                objects_to_remove.each { |remove_id| association.delete association.detect { |obj| obj.id.to_s == remove_id.to_s } }
                instance_variable_set removal_variable_name(association_id), nil
              end
            end
          end
        end
      end
      
      def removal_variable_name(association_id) #:nodoc:
        "@#{association_id.to_s.pluralize}_to_remove"
      end
    
    module ClassMethods
      
      # Behaves identically to the regular has_many, except adds the option <tt>:attributes</tt>, which, if true, creates
      # a method called association_id_attributes (i.e. task_attributes, or comment_attributes) for setting the attributes
      # of a collection of associated models. 
      #
      # It also adds the option <tt>:discard_if</tt>, which accepts a proc or a symbol. If the proc evaluates to true, the 
      # child model will be discarded. The symbol is sent as a message to the child model instance; if it returns true,
      # the child model will be discarded.
      # 
      # e.g.
      #
      #   :discard_if => proc { |comment| comment.title.blank? }
      #     or
      #   :discard_if => :blank? # where blank is defined in Comment
      #  
      #
      # The format is as follows:
      #
      #     @project.task_attributes = {
      #       @project.tasks.first.id => {:title => "A new title for an existing task"},
      #       :new => {
      #         "0" => {:title => "A new task"}
      #       }
      #     }
      #
      # Any existing tasks that are not present in the attributes hash will be removed from the association when the (parent) model
      # is saved.
      #
      def has_many_with_association_option(association_id, options = {}, &extension)
        unless (config = options.delete(:attributes)).nil?
          managed_association_attributes[association_id] = {}
          if options.has_key?(:discard_if)
            discard_if = options.delete(:discard_if)
            discard_if = discard_if.to_proc if discard_if.is_a?(Symbol)
            managed_association_attributes[association_id][:discard_if] = discard_if
          end
          collection_with_attributes_writer(association_id)
        end
        
        has_many_without_association_option(association_id, options, &extension)
      end
      
    private
    
      def collection_with_attributes_writer(association_name)
        define_method("#{association_name.to_s.singularize}_attributes=") do |attributes|
          has_many_attributes association_name, attributes
        end
      end
      
    end
    
  end # Associations
end # AttributeFu
