# Actify

[![Gem Version](https://badge.fury.io/rb/actify.svg)](https://badge.fury.io/rb/actify)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%202.6.0-ruby.svg)](https://www.ruby-lang.org/en/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Actify is a powerful Ruby gem that brings structured business actions to your Rails applications. It provides a clean, flexible way to define, manage, and track model-specific actions with built-in authorization, logging, and conditional execution.

## 📑 Table of Contents

- [Key Features](#key-features)
- [Installation](#installation)
- [Usage](#usage)
  - [Defining Actions](#defining-actions)
  - [Action Callbacks](#action-callbacks)
  - [Executing Actions](#executing-actions)
  - [Action Logging](#action-logging)
- [Configuration](#configuration)
- [Rails Integration](#rails-integration)
  - [RESTful API Controller](#restful-api-controller)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## ✨ Key Features

- **Structured Business Logic**: Define model-specific actions with clear, encapsulated logic
- **Built-in Authorization**: Add permission checks directly in your action definitions
- **Flexible Conditions**: Control action visibility and executability with custom conditions
- **Action Logging**: Automatic logging of action executions with actor tracking
- **Context-Aware**: Pass additional context data during action execution
- **Rails Integration**: Seamless integration with Rails applications

## 🚀 Installation

Add this line to your application's Gemfile:

```ruby
gem 'actify'
```

Then execute:

```bash
$ bundle install
```

Or install it directly:

```bash
$ gem install actify
```

Set up Actify in your Rails application:

```bash
$ bundle exec rails generate actify:install
```

This will create:
- The action_logs table migration
- An initializer for configuration

## 📖 Usage

### Defining Actions

Include the `Actify` module in your models and define actions using the `action` method:

```ruby
class Order < ApplicationRecord
  include Actify
  has_many :action_logs, as: :actionable

  action :approve, label: "Approve Order" do
    show? do |order, context|
      order.status == "pending"
    end

    authorized? do |order, context|
      context.actor.can_approve_orders?
    end

    commitable? do |order, context|
      order.items.all?(&:in_stock?)
    end

    commit do |order, context|
      order.update(
        status: "approved",
        approved_at: Time.current,
        approved_by: context.actor
      )
      OrderMailer.approval_notification(order).deliver_later
    end
  end
end
```

### Action Callbacks

Each action supports these callbacks:

| Callback | Purpose | Return Value |
|----------|---------|--------------|
| `show?` | Controls action visibility | Boolean |
| `authorized?` | Checks permission | Boolean |
| `commitable?` | Validates execution conditions | Boolean |
| `commit` | Contains execution logic | Any |

### Executing Actions

Execute actions using the `commit!` method:

```ruby
context = Actify::Context.new(
  actor: current_user,
  data: {
    reason: "Stock verified",
    notes: "Priority order"
  }
)

Order::Actions[:approve].commit!(order, context)
```

### Action Logging

Actify automatically logs action executions. Access logs through the `action_logs` association:

```ruby
# Get all logs for an order
order.action_logs

# Get logs for specific action
order.action_logs.where(action: "approve")
```

## ⚙️ Configuration

Customize Actify in `config/initializers/actify.rb`:

```ruby
Actify.configure do |config|
  # Custom logger
  config.logger = Rails.logger

  # Additional context processors
  config.add_context_processor do |context|
    context.merge(ip: Current.request_ip)
  end
end
```

## 🔌 Rails Integration

### RESTful API Controller

Here's an example of a RESTful API controller that can handle actions for any model:

```ruby
class ActionsController < ApplicationController
  before_action :get_object

  def create
    # Get the action from params and look it up in the model's Actions
    action_code = params[:action_code]&.to_sym
    action = @object_class::Actions[action_code]
    
    # Execute the action with context
    action_log = action.commit!(@object, get_context)

    # Return the action log as JSON
    if action_log.finished?
      render json: action_log.as_json(except: %i[object_before object_after])
    else
      render json: action_log.as_json(except: %i[object_before object_after]), 
             status: 400
    end
  end

  private

  OBJECT_NAME_REGEX = Regexp.new('/([^/]+)/[^/]+/actions')

  def get_context
    Actify::Context.new(
      actor: current_user,
      data: params[:action_data]
    )
  end

  def get_object
    # Extract model name from URL (e.g., /api/orders/123/actions)
    @object_name = request.url.match(OBJECT_NAME_REGEX)[1]
    @object_class = @object_name.classify.constantize
    
    # Find the object using conventional Rails ID parameter
    object_id_key = "#{@object_name.singularize}_id"
    object_id = params[object_id_key]
    @object = @object_class.find(object_id)
  end
end
```

This controller supports URLs like:
```
POST /api/v1/orders/123/actions
{
  "action_code": "approve",
  "action_data": {
    "reason": "Items in stock",
    "priority": "high"
  }
}
```

The controller:
1. Extracts the model name from the URL
2. Finds the target object
3. Looks up the requested action
4. Creates a context with the current user and action data
5. Executes the action and returns the result

This provides a standardized API endpoint for executing any action on any model that includes Actify.

## 📝 Examples

### State Machine-like Actions

```ruby
class Document < ApplicationRecord
  include Actify

  action :submit_for_review do
    show? { |doc| doc.draft? }
    commitable? { |doc| doc.content.present? }
    commit do |doc, context|
      doc.update(status: "in_review")
      notify_reviewers(doc, context.actor)
    end
  end

  action :approve do
    authorized? { |doc, context| context.actor.reviewer? }
    commit do |doc, context|
      doc.update(status: "approved")
    end
  end
end
```

## 🔧 Troubleshooting

Common issues and solutions:

1. **Actions not showing up?**
   - Ensure the model includes `Actify`
   - Check the `show?` callback conditions
   
2. **Action execution failing?**
   - Verify all callbacks (`authorized?`, `commitable?`) return true
   - Check if the context contains required data
   
3. **Logs not being created?**
   - Confirm the `action_logs` table exists
   - Ensure the model has `has_many :action_logs, as: :actionable`

## 🛠 Development

1. Clone the repository:
   ```bash
   git clone https://github.com/nguyenta99/actify.git
   ```

2. Install dependencies:
   ```bash
   bin/setup
   ```

3. Run tests:
   ```bash
   rake spec
   ```

4. Start console:
   ```bash
   bin/console
   ```

## 👥 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read [CODE_OF_CONDUCT.md](https://github.com/nguyenta99/actify/blob/master/CODE_OF_CONDUCT.md) for details on our code of conduct.

## 📄 License

Released under the MIT License. See [LICENSE.txt](https://github.com/nguyenta99/actify/blob/master/LICENSE.txt) for details.

---
Built with ❤️ by [nguyenta99](https://github.com/nguyenta99)
