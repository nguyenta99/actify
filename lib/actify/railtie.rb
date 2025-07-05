# frozen_string_literal: true

require "rails/railtie"
require "rails/generators"

module Actify
  # Railtie to integrate Actify with Rails
  class Railtie < Rails::Railtie
    # Load custom Rails commands
    railtie_name :actify

    generators do
      require File.expand_path("../generators/actify/install_generator", __FILE__)
    end
  end
end
