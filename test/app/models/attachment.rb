require 'uuidtools'
class Attachment < ActiveRecord::Base
  FILE_STORE = File.join(RAILS_ROOT, 'public', 'attach_test')
  S3_BUCKET = 'attach_test'

  serialize :metadata, Hash

  attr_protected([:mime_type, :size, :filename, :digest])

  fssp = Proc.new {|i, e| "file://localhost#{::File.join(FILE_STORE, [i, e].join('.'))}"}
  s3sp = Proc.new {|i, e| "s3:/#{::File.join(S3_BUCKET, [i, e].join('.'))}"}
  dbsp = Proc.new {|i, e| "db:/#{i}"}
  mock = Proc.new {|i, e| "memory:/#{[i, e].join('.')}"}
  has_attachment(:size => 0.byte..15.megabytes, :store => mock)

  validates_as_attachment

  def to_s
    self[:description] || self[:filename] || self[:uri] || 'Attachment'
  end

  # Return a unique id used to tag this attachment's data.
  def uuid!
    @uuid ||= ::UUID.timestamp_create.to_s
  end
end