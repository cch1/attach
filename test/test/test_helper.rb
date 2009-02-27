ENV['RAILS_ENV'] ||= 'test'
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'

# From this point forward, we can assume that we have booted a generic Rails environment plus
# our (booted) plugin.
load(RAILS_ROOT + "/db/schema.rb")

# Run the migrations (optional)
# ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate")

# Set Test::Unit options for optimal performance/fidelity.
class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
#  self.fixture_path = "#{RAILS_ROOT}/../fixtures"
  
  def self.uses_mocha(description)
    require 'mocha'
    yield
  rescue LoadError
    $stderr.puts "Skipping #{description} tests. `gem install mocha` and try again."
  end
end