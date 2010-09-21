require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the attach plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test/lib'
  t.pattern = 'test/test/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the attach plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Attach'
  rdoc.options << '--line-numbers --inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
