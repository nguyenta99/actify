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
