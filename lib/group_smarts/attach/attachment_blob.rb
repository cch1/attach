class GroupSmarts::Attach::AttachmentBlob < ActiveRecord::Base
  belongs_to :attachment if table_exists?

  # Summarize blob data
  def inspect
    self.attributes(:except => :blob).merge({:blob => (blob.nil? ? nil : "#{blob.size/1024}K blob")}).inspect
  end
end