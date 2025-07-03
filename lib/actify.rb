# frozen_string_literal: true

require_relative "actify/version"

module Actify
  class Error < StandardError; end

  def self.perform(action)
    "Performing: #{action}"
  end
end
