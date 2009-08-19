module JrailsAutoComplete
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def auto_complete_for(object_name, method_name, options = {})
      self.send(:define_method, "auto_complete_for_#{object_name}_#{method_name}") do
        find_options = {
          :conditions => [ "LOWER(#{method}) LIKE ?", '%' + params[object][method].downcase + '%' ],
          :order => "#{method} ASC",
          :limit => 10
        }.merge!(options)

        @items = object.to_s.camelize.constantize.find(:all, find_options)
        render :inline => "<%= auto_complete_result @items, '#{method}' %>"
      end
    end
  end
end