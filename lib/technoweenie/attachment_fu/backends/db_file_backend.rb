class DbFile < ActiveRecord::Base
  belongs_to :attachment

  # Summarize blob data
  def inspect
    self.attributes(:except => :data).merge({:data => (self.data.nil? ? nil : "#{self.data.size/1024}K blob")}).inspect
  end
end

module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # Methods for DB backed attachments
      module DbFileBackend
        def self.included(base) #:nodoc:
          base.has_one :db_file, :class_name => '::DbFile', :foreign_key => 'attachment_id', :dependent => :destroy
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
            # All the hard work is done by Rails with the :dependent => :destroy association option.
          end
          
          # Saves the data to the DbFile model
          def save_to_storage
            if save_attachment?
              (db_file || build_db_file).data = temp_data
              db_file.save!
            end
            true
          end
      end
    end
  end
end