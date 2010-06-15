class Hapgood::Attach::AttachmentBlob < ActiveRecord::Base
  # Summarize blob data
  def inspect
    safe_attributes = self.attributes
    safe_attributes.delete('blob')
    safe_attributes.merge({:blob => (blob.nil? ? nil : "#{blob.size/1024}K blob")}).inspect
  end
end