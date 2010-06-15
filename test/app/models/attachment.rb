require 'uuidtools'
class Attachment < ActiveRecord::Base
  FILE_STORE = File.join(RAILS_ROOT, 'public', 'attachments')
  S3_BUCKET = 'attach_test'

  serialize :metadata, Hash

  attr_protected([:mime_type, :size, :filename, :digest])

  fssp = Proc.new {|i, a, e| "file://localhost#{::File.join(FILE_STORE, [[i,a].compact.join('_'), e].join('.'))}"}
  s3sp = Proc.new {|i, a, e| "s3:/#{::File.join(S3_BUCKET, [[i,a].compact.join('_'), e].join('.'))}"}
  dbsp = Proc.new {|i, a, e| "db:/#{i}"}
  has_attachment(:size => 0.byte..15.megabytes, :store => fssp)
  
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