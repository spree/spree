class PaperclipGenerator < Rails::Generator::NamedBase
  attr_accessor :attachments, :migration_name
 
  def initialize(args, options = {})
    super
    @class_name, @attachments = args[0], args[1..-1]
  end
 
  def manifest    
    file_name = generate_file_name
    @migration_name = file_name.camelize
    record do |m|
      m.migration_template "paperclip_migration.rb.erb",
                           File.join('db', 'migrate'),
                           :migration_file_name => file_name
    end
  end 
  
  private 
  
  def generate_file_name
    names = attachments.map{|a| a.underscore }
    names = names[0..-2] + ["and", names[-1]] if names.length > 1
    "add_attachments_#{names.join("_")}_to_#{@class_name.underscore}"
  end
 
end
