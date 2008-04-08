module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # Methods for DB backed attachments
      module DbFileBackend
        def self.included(base) #:nodoc:
          Object.const_set(:DbFile, Class.new(ActiveRecord::Base)) unless Object.const_defined?(:DbFile)
          base.belongs_to  :db_file, :class_name => '::DbFile', :foreign_key => 'db_file_id'
        end

        # Creates a temp file with the current db data.
        def create_temp_file
          write_to_temp_file current_data
        end
        
        # Gets the current data from the database
        def current_data
          db_file.data
        end
        
        protected
          # Destroys the file.  Called in the after_destroy callback
          def destroy_file
            db_file.destroy if db_file
          end
          
          # Saves the data to the DbFile model
          def save_to_storage
            if save_attachment?
              (db_file || build_db_file).data = temp_data
              db_file.save!
              self.class.update_all ['db_file_id = ?', self.db_file_id = db_file.id], ['id = ?', id]
            end
            true
          end
      end
    end
  end
end