config.after_initialize do
  require 'db/schema.rb'
  require 'active_record/fixtures'
  require 'hapgood/attach/attachment_blob'
  Fixtures::FILE_STORE = File.join(RAILS_ROOT, 'test', 'fixtures', 'attachments')
  Fixtures.create_fixtures('test/fixtures', [:attachments, :attachment_blobs, :users], :attachment_blobs => Hapgood::Attach::AttachmentBlob)
end