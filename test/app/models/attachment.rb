require 'uuidtools'
class Attachment < ActiveRecord::Base
  serialize :metadata, Hash
  include ActionController::UrlWriter

  attr_protected([:mime_type, :size, :filename, :digest])

  belongs_to :attachee, :polymorphic => true

  has_attachment({:store => "file://localhost/#{Rails.root}/public/attachments/%s", :_aspects => [:thumbnail], :size => 1.byte..15.megabytes})
  
  validates_as_attachment

  def initialize(attrs = {})
    attrs = attrs || {} # Why is this necessary?  Try Attachment.new and see.
    raise "Ambiguous attachment type." if (attrs[:url] && attrs[:file])
    super
  end

  def self.exrep_methods
    [primary_key] + (content_columns.map(&:name) - %w(attachee_type attachee_id updated_at digest uri) + %w(src b64digest)).sort
  end

  # Return a URL representing this attachment, which could be a remote URL or a local URL.
  # TODO: return relative URLs that can be served directly by Apache.
  def http_url
    local? ? polymorphic_url([attachee, self], :format => self.mime_type.to_sym) : self[:uri]
  end
  alias src http_url

  def b64digest
    digest && Base64.encode64(digest).chomp!
  end
  
  def to_s
    returning "" do |s|
      s << (self[:description] || self[:filename] || self[:uri] || 'Attachment')
      s << " [#{self[:aspect]}]" if self[:aspect]
    end
  end
  
  # Return a unique id used to tag this attachment's data.
  def uuid!
   @uuid ||= ::UUID.timestamp_create.to_s 
  end
end