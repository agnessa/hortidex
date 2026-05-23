# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  minimum_coverage 98
end

require "bundler/setup"
require "with_model"
require "hortidex"
require_relative "support/database"

RSpec.configure do |config|
  config.extend WithModel
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
