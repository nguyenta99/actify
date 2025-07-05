# frozen_string_literal: true

require "actify/railtie" if defined?(Rails)
require_relative "actify/version"
require_relative "action"

# This module allows models to define and execute custom actions with various hooks,
# authorization checks, and lifecycle callbacks.
module Actify
  def self.included(base)
    return if base.const_defined?(:Actions)

    base.const_set :Actions, (Module.new do
      def self.all
        @actions
      end

      def self.[](code)
        (@actions || {})[code]
      end
    end)

    class << base
      def use_policy_in_actionable(accept = true) # rubocop:disable Style/OptionalBooleanParameter
        @use_policy = accept
      end

      def action(name, options = {}, &block)
        options["use_policy"] = @use_policy if (options.keys & [:use_policy, "use_policy"]).empty?
        action_def = Def.new(name, options)

        existing_action = const_get(:Actions).class_eval do
          (@actions || {})[name]
        end

        if existing_action
          action_def.action = existing_action
          action_def.with_options(options)
        end

        action_def.instance_eval(&block) if block_given?

        const_get(:Actions).class_eval do
          @actions ||= {}
          @actions[name] = action_def.action
        end
      end
    end

    base.action :create, label: "Create" do
      show? { false }
      commit do |object, ctx|
      end
    end

    base.action :update, label: "Update" do
      show? { false }
      commit do |object, ctx|
      end
    end
  end

  # Context class to hold action context data
  # It is a Hash-like object that provides access to common attributes like actor, data
  class Context < Hash
    %i[actor data].each do |attr_name|
      define_method attr_name do
        self[attr_name]
      end

      define_method "#{attr_name}=".to_sym do |value|
        self[attr_name] = value
      end
    end

    def initialize(options = {}) # rubocop:disable Lint/MissingSuper
      # TODO: check option validity
      options.each do |key, value|
        self[key] = value
      end
    end
  end

  class Def # rubocop:disable Style/Documentation
    attr_accessor :action

    def initialize(name, options = {})
      @action = Action.new
      @action.code = name

      with_options options
    end

    def with_options(options)
      options.each do |key, value|
        send(key.to_s, value)
      end
    end

    def label(label)
      @action.label = label
    end

    def order(order)
      @action.order = order
    end

    def type(type)
      @action.type = type
    end

    def use_policy(use_policy)
      @action.use_policy = use_policy
    end

    def execute_before_action(action_code, options = {})
      @action.before_actions << {
        action_code: action_code,
        options: options
      }
    end

    def execute_after_action(action_code, options = {})
      @action.after_actions << {
        action_code: action_code,
        options: options
      }
    end

    def show?(&block)
      @action.hdl_show = block
    end

    def authorized?(&block)
      @action.hdl_authorized = block
    end

    def commitable?(&block)
      @action.hdl_commitable = block
    end

    def commit(&block)
      @action.hdl_commit = block
    end

    def finalize(&block)
      @action.hdl_finalize = block
    end
  end

  class Error < StandardError
  end

  class ActorMissingError < Error
  end

  class InvalidDataError < Error
  end
end
