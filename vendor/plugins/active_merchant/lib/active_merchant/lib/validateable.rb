module ActiveMerchant #:nodoc:  
  module Validateable #:nodoc:
    def valid?
      errors.clear

      before_validate if respond_to?(:before_validate, true)
      validate if respond_to?(:validate, true)

      errors.empty?
    end  

    def initialize(attributes = {})
      self.attributes = attributes
    end

    def errors    
      @errors ||= Errors.new(self)
    end

    private

    def attributes=(attributes)
      unless attributes.nil?
        for key, value in attributes
          send("#{key}=", value )            
        end
      end
    end  

    # This hash keeps the errors of the object
    class Errors < HashWithIndifferentAccess

      def initialize(base)
        @base = base
      end
      
      def count
        size
      end

      # returns a specific fields error message. 
      # if more than one error is available we will only return the first. If no error is available 
      # we return an empty string
      def on(field)
        self[field].to_a.first
      end

      def add(field, error)
        self[field] ||= []
        self[field] << error
      end    
      
      def add_to_base(error)
        add(:base, error)
      end

      def each_full
        full_messages.each { |msg| yield msg }      
      end

      def full_messages
        result = []

        self.each do |key, messages| 
          if key == 'base'
            result << "#{messages.first}"
          else
            result << "#{key.to_s.humanize} #{messages.first}"
          end
        end

        result
      end   
    end  
  end
end