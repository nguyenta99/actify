# frozen_string_literal: true

class Action # rubocop:disable Metrics/ClassLength,Style/Documentation
  attr_accessor :code, :label, :order, :use_policy, :after_actions, :before_actions, :hdl_show, :hdl_authorized,
                :hdl_commitable, :hdl_commit, :hdl_finalize

  def initialize
    @order = 0
    @after_actions = []
    @before_actions = []
    @error = nil
  end

  def commit!(object, context)
    execute(object, context)
  end

  def show?(object, context)
    if use_policy
      if hdl_show
        instance_exec(object, context, &hdl_show)
      else
        authorized?(object, context) && commitable?(object, context)
      end
    else
      !hdl_show || instance_exec(object, context, &hdl_show)
    end
  end

  def authorized?(object, context) # rubocop:disable Metrics/MethodLength
    # if use_policy
    #   if hdl_authorized
    #     instance_exec(object, context, &hdl_authorized)
    #   else
    #     context_for_policy = context.merge({ user: context[:actor] })
    #     policy = Pundit.policy!(context_for_policy, object)
    #     policy.send("#{code}?")
    #   end
    # else
    #   !hdl_authorized || instance_exec(object, context, &hdl_authorized)
    # end
    !hdl_authorized || instance_exec(object, context, &hdl_authorized)
  end

  def commitable?(object, context)
    !hdl_commitable || instance_exec(object, context, &hdl_commitable)
  end

  def after_action?(action_code)
    !!after_actions.detect { |after_action| after_action[:action_code] == action_code }
  end

  def before_action?(action_code)
    !!before_actions.detect { |before_action| before_action[:action_code] == action_code }
  end

  private

  def commit(object, context)
    instance_exec object, context, &hdl_commit
  end

  def verify_context(context)
    return if context.actor

    raise Actify::ActorMissingError, "Actor is required to commit action"
  end

  def execute(object, context) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    verify_context(context)

    log = initialize_action_log(object, context)

    if !(commitable = authorized?(object, context))
      log.status = ActionLog.statuses[:aborted]
      log.error = { message: "Unauthorized" }
    elsif !(commmitable = commitable && commitable?(object, context))
      log.status = ActionLog.statuses[:aborted]
      log.error = { message: "Wrong context" }
    end

    if commmitable
      begin
        execute_before_actions object, context

        commit object, context

        execute_after_actions object, context

        log.status = ActionLog.statuses[:finished]
      rescue StandardError => e
        log.status = ActionLog.statuses[:aborted]
        log.error = { message: e.message }
      end
    end

    finalize_action_log log, object, context

    log
  end

  def finalize_action_log(log, object, context)
    object_before = {}
    object_after = {}

    object.previous_changes.each do |k, v|
      object_before[k] = v[0]
      object_after[k] = v[1]
    end

    log.object_before = object_before
    log.object_after = object_after

    instance_exec(log, object, context, &hdl_finalize) if hdl_finalize

    log.save!
  end

  def execute_before_actions(object, context)
    to_run_actions = object.class::Actions.all.select do |_code, action|
      action.before_action? code
    end

    to_run_actions.each_value do |action|
      # if action.executable?(context, object, params)
      action.commit! object, context
      # end
    end
  end

  def execute_after_actions(object, context)
    to_run_actions = object.class::Actions.all.select do |_code, action|
      action.after_action? code
    end

    to_run_actions.each_value do |action|
      # if action.executable?(context, object, params)
      action.commit! object, context
      # end
    end
  end

  def initialize_action_log(object, context) # rubocop:disable Metrics/MethodLength
    ActionLog.create!(
      status: ActionLog.statuses[:created],
      actor_id: context.actor.id,
      actionable: object,
      action_code: code,
      action_label: label,
      action_data: context.data.to_s,
      context: context.to_s,
      object_before: object.to_s
    )
  end
end
