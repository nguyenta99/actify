require "rails/generators"
require "rails/generators/migration"

module Actify
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("../../../templates", __FILE__)
      desc "Creates a migration for action_logs table"

      def copy_migration
        migration_template(
          "create_action_logs.rb.tt",
          "db/migrate/create_action_logs.rb",
          migration_version: migration_version
        )
      end

      def copy_model
        template "action_log.rb.tt", "app/models/action_log.rb"
      end

      def run_migration
        say_status("migrating", "Running `rails db:migrate`", :green)
        rake("db:migrate")
      end

      def self.next_migration_number(dirname)
        if @prev_migration_nr
          @prev_migration_nr += 1
        else
          timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
          @prev_migration_nr = timestamp.to_i
        end

        @prev_migration_nr.to_s
      end

      private

      # Detect version from Rails project
      def migration_version
        "[#{ActiveRecord::Migration.current_version.to_s[0..2]}]"
      end
    end
  end
end
