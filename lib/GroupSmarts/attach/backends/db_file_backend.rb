require File.join(File.dirname(__FILE__), 'db_file')
module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Backends
      # Methods for DB backed attachments
      module DbFileBackend
        def self.included(base) #:nodoc:
          base.has_one :db_file, :foreign_key => 'attachment_id', :dependent => :destroy
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
            # All the hard work is done by Rails with the :dependent => :destroy association option.
          end
          
          # Saves the data to the DbFile model
          def save_to_storage
            if save_attachment?
              (db_file || build_db_file).data = source.data
              db_file.save!
            end
            true
          end
      end
    end
  end
end