module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # Methods for DB backed attachments
      module DbFileBackend
        def self.included(base) #:nodoc:
#          Object.const_set(:DbFile, Class.new(ActiveRecord::Base)) unless Object.const_defined?(:DbFile)
          base.belongs_to  :db_file, :class_name => '::DbFile', :foreign_key => 'db_file_id'
        end

        # This method is intended to return the filename of the attachment.  For the db_file backend, it is only 
        # used when initializing the temp_paths variable -and then only as check for a potential optimization.  
        # For the db_file backend, it is sufficient to return a path to a file that does not exist.
        def full_filename(thumbnail = nil)
          returning File.join(RAILS_ROOT, "NonExistantFile") do |f|
            raise "Intentionally missing file is not missing! #{f}" if File.exist?(f)
          end
        end

        # Creates a temp file with the current db data.
        def create_temp_file
          write_to_temp_file current_data
        end
        
        # Gets the current data from the database
        def current_data
          db_file.data
        end

        # Returns true if the attachment is stored locally.
        def attachment_present?
          !db_file.nil?
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
              self.class.update_all ['db_file_id = ?', self.db_file_id = db_file.id], ["#{self.class.primary_key} = ?", id]
            end
            true
          end
      end
    end
  end
end