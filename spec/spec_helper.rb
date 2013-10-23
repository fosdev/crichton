SPEC_DIR = File.expand_path("..", __FILE__)
lib_dir = File.expand_path("../lib", SPEC_DIR)
LINT_DIR = File.expand_path("../lib/lint", SPEC_DIR)

$LOAD_PATH.unshift(lib_dir)
$LOAD_PATH.uniq!

require 'rspec'
require 'debugger'
require 'bundler'
require 'equivalent-xml'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

Debugger.start
Bundler.setup

require 'crichton'
load 'Rakefile'

Dir["#{SPEC_DIR}/support/*.rb"].each { |f| require f }

Crichton::config_directory = File.join('spec', 'fixtures', 'config')

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random' unless ENV['RANDOMIZE'] == 'false'

  config.include Support::Helpers
  config.include Support::ALPS
  config.include Support::Controllers

  config.before(:each) { Crichton::config_directory = File.join('spec', 'fixtures', 'config') }
end
