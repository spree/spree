module ActivePresenter
  # Base class for presenters. See README for usage.
  #
  class Base
    class_inheritable_accessor :presented
    self.presented = {}
    
    # Indicates which models are to be presented by this presenter.
    # i.e.
    #
    #   class SignupPresenter < ActivePresenter::Base
    #     presents User, Account
    #   end
    #
    #
    def self.presents(*types)
      attr_accessor *types
      
      types.each do |t|
        define_method("#{t}_errors") do
          send(t).errors
        end
        
        presented[t] = t.to_s.tableize.classify.constantize
      end
    end
    
    def self.human_attribute_name(attribute_name)
      presentable_type = presented.keys.detect do |type|
        attribute_name.to_s.starts_with?("#{type}_")
      end
      
      attribute_name.to_s.gsub("#{presentable_type}_", "").humanize
    end
    
    attr_accessor :errors
    
    # Accepts arguments in two forms. For example, if you had a SignupPresenter that presented User, and Account, you could specify arguments in the following two forms:
    #
    #   1. SignupPresenter.new(:user_login => 'james', :user_password => 'swordfish', :user_password_confirmation => 'swordfish', :account_subdomain => 'giraffesoft')
    #     - This form is useful for initializing a new presenter from the params hash: i.e. SignupPresenter.new(params[:signup_presenter])
    #   2. SignupPresenter.new(:user => User.find(1), :account => Account.find(2))
    #     - This form is useful if you have instances that you'd like to edit using the presenter. You can subsequently call presenter.update_attributes(params[:signup_presenter]) just like with a regular AR instance.
    #
    # Both forms can also be mixed together: SignupPresenter.new(:user => User.find(1), :user_login => 'james')
    #   In this case, the login attribute will be updated on the user instance provided.
    # 
    # If you don't specify an instance, one will be created by calling Model.new
    #
    def initialize(args = {})
      args ||= {}
      
      presented.each do |type, klass|
        send("#{type}=", args[type].is_a?(klass) ? args.delete(type) : klass.new)
      end
      
      self.attributes = args
    end
    
    # Set the attributes of the presentable instances using the type_attribute form (i.e. user_login => 'james')
    #
    def attributes=(attrs)
      attrs.each { |k,v| send("#{k}=", v) unless attribute_protected?(k)}
    end
    
    # Makes sure that the presenter is accurate about responding to presentable's attributes, even though they are handled by method_missing.
    #
    def respond_to?(method)
      presented_attribute?(method) || super
    end
    
    # Handles the decision about whether to delegate getters and setters to presentable instances.
    #
    def method_missing(method_name, *args, &block)
      presented_attribute?(method_name) ? delegate_message(method_name, *args, &block) : super
    end
    
    # Returns an instance of ActiveRecord::Errors with all the errors from the presentables merged in using the type_attribute form (i.e. user_login).
    #
    def errors
      @errors ||= ActiveRecord::Errors.new(self)
    end
    
    # Returns boolean based on the validity of the presentables by calling valid? on each of them.
    #
    def valid?
      presented.keys.each do |type|
        presented_inst = send(type)
        
        merge_errors(presented_inst, type) unless presented_inst.valid?
      end
      
      errors.empty?
    end
    
    # Save all of the presentables, wrapped in a transaction.
    # 
    # Returns true or false based on success.
    #
    def save
      saved = false
      
      ActiveRecord::Base.transaction do
        if valid?
          saved = presented_instances.map { |i| i.save(false) }.all?
          raise ActiveRecord::Rollback unless saved # TODO: Does this happen implicitly?
        end
      end
      
      saved
    end
    
    # Save all of the presentables, by calling each of their save! methods, wrapped in a transaction.
    #
    # Returns true on success, will raise otherwise.
    # 
    def save!
      ActiveRecord::Base.transaction do
        valid? # collect errors before potential exception raise
        presented_instances.each { |i| i.save! }
      end
    end
    
    # Update attributes, and save the presentables
    #
    # Returns true or false based on success.
    #
    def update_attributes(attrs)
      self.attributes = attrs
      save
    end
    
    protected
      def presented_instances
        presented.keys.map { |key| send(key) }
      end
      
      def delegate_message(method_name, *args, &block)
        presentable = presentable_for(method_name)
        send(presentable).send(flatten_attribute_name(method_name, presentable), *args, &block)
      end
      
      def presentable_for(method_name)
        presented.keys.detect do |type|
          method_name.to_s.starts_with?(attribute_prefix(type))
        end
      end
    
      def presented_attribute?(method_name)
        p = presentable_for(method_name)
        !p.nil? && send(p).respond_to?(flatten_attribute_name(method_name,p))
      end
      
      def flatten_attribute_name(name, type)
        name.to_s.gsub(/^#{attribute_prefix(type)}/, '')
      end
      
      def attribute_prefix(type)
        "#{type}_"
      end
      
      def merge_errors(presented_inst, type)
        presented_inst.errors.each do |att,msg|
          errors.add(attribute_prefix(type)+att, msg.to_s)
        end
      end
      
      def attribute_protected?(name)
        presentable    = presentable_for(name)
        flat_attribute = {flatten_attribute_name(name, presentable) => ''} #remove_att... normally takes a hash, so we use a ''
        presentable.to_s.tableize.classify.constantize.new.send(:remove_attributes_protected_from_mass_assignment, flat_attribute).empty?
      end
  end
end
