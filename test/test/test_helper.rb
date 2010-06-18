ENV['RAILS_ENV'] ||= 'test'
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

# From this point forward, we can assume that we have booted a generic Rails environment plus
# our (booted) plugin.
load(RAILS_ROOT + "/db/schema.rb")

# Run the migrations (optional)
# ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate")

Fixtures::FILE_STORE = File.join(RAILS_ROOT, 'test', 'fixtures', 'attachments')

# Set Test::Unit options for optimal performance/fidelity.
class ActiveSupport::TestCase
  def self.uses_mocha(description)
    require 'mocha'
    yield
  rescue LoadError
    $stderr.puts "Skipping #{description} tests. `gem install mocha` and try again."
  end
  set_fixture_class :attachment_blobs => Hapgood::Attach::AttachmentBlob

  def stubbed_source(options = {})
    @stubbed_source ||= stub('simple source') do
      fn = options[:filename] || "plus.png"
      blob = options[:blob] || Pathname.new(::Fixtures::FILE_STORE).join(fn).read
      mt = options[:mime_type] || Mime::Type.lookup_by_extension(Pathname.new(fn).extname[1..-1] || 'png')
      digest = Digest::MD5.digest(blob)
      size = blob.length
      tempfile = Tempfile.new(fn).tap{|tmp| tmp.write blob;tmp.close}
      stubs(:blob).returns blob
      stubs(:io).returns StringIO.new(blob, 'r+b')
      stubs(:tempfile).returns tempfile
      stubs(:mime_type).returns mt
      stubs(:filename).returns fn
      stubs(:size).returns size
      stubs(:digest).returns digest
      stubs(:metadata).returns({:size => size, :mime_type => mt, :filename => fn, :digest => digest})
      stubs(:uri).returns nil
      stubs(:persistent?).returns false
    end
  end
end