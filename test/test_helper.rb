# frozen_string_literal: true
require "simplecov"
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pluck_all'

require 'minitest/autorun'

ActiveRecord::Base.establish_connection(
  "adapter"  => "sqlite3",
  "database" => ":memory:",
)
require_relative 'carrierwave_test_helper'
require_relative 'lib/seeds'
