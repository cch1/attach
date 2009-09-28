require 'uuidtools'
class Attachment < ActiveRecord::Base
  FILE_STORE = "#{RAILS_ROOT}/public/attachments"

  serialize :metadata, Hash

  attr_protected([:mime_type, :size, :filename, :digest])

  has_attachment(:size => 0.byte..15.megabytes)
  
  validates_as_attachment

  def to_s
    returning "" do |s|
      s << (self[:description] || self[:filename] || self[:uri] || 'Attachment')
      s << " [#{self[:aspect]}]" if self[:aspect]
    end
  end
  
  before_save_attachment do |a|
    a.description ||= "Default Attachment Description"
  end

  before_save_aspect do |a|
    a.description ||= "Default Aspect Description"
  end

  # Return a unique id used to tag this attachment's data.
  def uuid!
    @uuid ||= ::UUID.timestamp_create.to_s 
  end
end