# frozen_string_literal: true

# The custom reporters aren't compatible with RubyMine's Minitest integration.
unless ENV['RM_INFO']
  require 'minitest/reporters'

  reporters =
    if ENV['CI']
      # In CI, we want both standard output status reporting,
      # but also JUnit report generation.
      [
        Minitest::Reporters::SpecReporter.new,
        Minitest::Reporters::JUnitReporter.new('test/reports', false)
      ]
    else
      # Otherwise, just enable the default set of reporters.
      [Minitest::Reporters::ProgressReporter.new]
    end

  # Configure the desired reporters, and preserve Rails' predefined backtrace filter
  Minitest::Reporters.use!(reporters, ENV, Minitest.backtrace_filter)
end

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'

  if ENV['CI']
    # In CI, we want to write code coverage results in Cobertura format as well
    require 'simplecov-cobertura'
    SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  end
end

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/autorun'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Include all FactoryBot methods
    include FactoryBot::Syntax::Methods
  end
end
