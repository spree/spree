
module EnumerableConstant
  
  # default (overridable) value for any
  def self.any_value
    -1
  end
  
  def self.any
    [any_value, '[any]']
  end
  
  class Tupple
    
    include Comparable
    
    attr_accessor :name, :value, :display_name
    
    def initialize(name, value=nil, display_name=nil)
      @name = name
      @value = value
      @display_name = display_name
    end
    
    def <=> other
      self.display_name <=> other.display_name
    end
    
    def title_translated
      t("order_status_#{self.name.downcase}")
    end
    
    def title
      if @display_name
        self.display_name
      else
        self.name.titleize.strip
      end
    end
    
    def id
      self.value
    end
    
  end
  
  class Base
    
    include Comparable

    def <=>
      
    end
    
    def self.class_var_prefix
      self.name.gsub!('::', '_').underscore
    end

    def self.base=(value)
      class_eval("@@#{self.class_var_prefix}_base = value")
    end

    def self.base(value)
      class_eval("@@#{self.class_var_prefix}_base = value")
    end

    def self.constant(name, value=nil, display_name=nil)
      # puts "name: #{name}"
      # puts "value: #{value}"
      # puts "display_name: #{display_name}"
      class_eval("@@#{self.class_var_prefix}_constants ||= []")
      class_eval("@@#{self.class_var_prefix}_base ||= 0 ")
      if value == nil and class_eval("@@#{self.class_var_prefix}_constants.size == 0")
        value = class_eval("@@#{self.class_var_prefix}_base")
      end
      if value == nil and class_eval("@@#{self.class_var_prefix}_constants.size > 0")
        begin
          value = class_eval("@@#{self.class_var_prefix}_constants.last.value.succ")
        rescue
          value = nil
        end
      end
      # puts "eval : " + "#{name.to_s.underscore.upcase} = #{value}"
      class_eval "#{name.to_s.underscore.upcase} = #{value}"
      # class_eval "A_STUFF = 25"
      # puts "display_name: #{display_name}" if display_name
      class_eval("@@#{self.class_var_prefix}_constants << EnumerableConstant::Tupple.new(name, value, display_name)")
    end
    
    # TODO: add method_missing for class methods so you can do stuff like:
    # :my_constant = 2
    # :my_constant 2
    # MY_CONSTANT = 2
    # MY_CONSTANT 2
    # def self.method_missing(symbol, *params)
    #  
    # end
    def self.from_value value
      self.constants.each do |constant|
        return constant.title if constant.value == value
      end
      nil
    end
    
    def self.constants
      class_eval("@@#{self.class_var_prefix}_constants")
    end
    
    def self.constant_names
      result = []
      class_eval("@@#{self.class_var_prefix}_constants").map do |tupple|
        result << tupple.name
      end
      result
    end
    
    def self.names
      result = []
      class_eval("@@#{self.class_var_prefix}_constants").map do |tupple|
        result << tupple.title
      end
      result
    end
    
    def self.values
      result = []
      class_eval("@@#{self.class_var_prefix}_constants").map do |tupple|
        result << tupple.value
      end
      result
    end
    
  end
  
  module VERSION
    MAJOR = 1
    MINOR = 0
    TINY  = 0
    STRING = [MAJOR, MINOR, TINY].join('.')
  end
  
end

class ActiveRecord::Base
  
  def self.enumerable_constant(attribute_name, options={})
    raise ArgumentError, "you must specify a list of constants" unless options[:constants]
    set_name = attribute_name.to_s.camelize
    set_class = "#{self.name}::#{set_name}"
    
    constant_definitions = ""
    options[:constants].each do |constant|
      if constant.is_a? Hash
        # puts "hash"
        constant_name = constant.to_a[0][0]
        display_name = constant.to_a[0][1]
        # puts "constant name: #{constant_name}"
        # puts "display name: #{display_name}"
        # puts "c name: #{constant_name.to_s.underscore.upcase}"
        constant_definitions << "constant '#{constant_name.to_s.underscore.upcase}', nil, '#{display_name}'\n" 
      else
        # puts "constant '#{constant.to_s.underscore.upcase}'\n" 
        constant_definitions << "constant '#{constant.to_s.underscore.upcase}'\n" 
      end
    end
    
    # allow for :connector and :skip_last_comma as used in Array#to_sentence
    if options[:connector]
      connector = options[:connector] 
    else
      connector = 'or'
    end
    unless options[:skip_last_comma].kind_of? NilClass
      skip_last_comma = options[:skip_last_comma] 
    else
      skip_last_comma = true
    end
    
    if options[:base]
      use_base = options[:base]
    else
      use_base = 1
    end

    # keep glue_text for back compat
    if options[:glue_text]
      connector = options[:glue_text].strip
    end    

    class_eval <<-EOF
      class #{set_name} < EnumerableConstant::Base
        base #{use_base}
        #{constant_definitions}
      end
    EOF

    should_be_in_text = set_class.constantize.names.to_sentence :words_connector => connector, :last_word_connector => skip_last_comma
  
    unless options[:no_validation]
      class_eval <<-EOF  
        validates :#{attribute_name.to_s}, :presence => {
          :in => #{set_name}::values, 
          :message => "should be #{should_be_in_text}"
          }
      EOF
    end
  end
  
end
