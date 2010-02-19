module JrailsAutoComplete
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def auto_complete_for(object_name, method_name, options = {})
      self.send(:define_method, "auto_complete_for_#{object_name}_#{method_name}") do
        find_options = {
          :conditions => [ "LOWER(#{method_name}) LIKE ?", '%' + params[object_name][method_name].downcase + '%' ],
          :order => "#{method_name} ASC",
          :limit => 10
        }.merge!(options)

        @items = object_name.to_s.camelize.constantize.find(:all, find_options)
        render :inline => "<%= auto_complete_result @items, '#{method_name}' %>"
      end
    end
  end
end