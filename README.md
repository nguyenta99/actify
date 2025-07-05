# Actify

[![Gem Version](https://badge.fury.io/rb/actify.svg)](https://badge.fury.io/rb/actify)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%202.6.0-ruby.svg)](https://www.ruby-lang.org/en/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> A Ruby on Rails gem for adding structured business actions to your models with authorization and logging.

---

## 🎯 What is Actify?

Actify helps you organize your Rails application's business logic into clear, reusable actions. Instead of scattering business logic across controllers and models, Actify lets you:

- Define actions right in your models
- Add permission checks automatically
- Track who did what and when
- Control when actions can be performed

**Perfect for:**
- Approval workflows
- State transitions
- User operations
- Audit logging

---

## 📚 Table of Contents

1. [Quick Start](#-quick-start)
2. [Basic Concepts](#-basic-concepts)
3. [Installation](#-installation)
4. [Simple Example](#-simple-example)
5. [Advanced Usage](#-advanced-usage)
6. [Rails Integration](#-rails-integration)
7. [Configuration](#%EF%B8%8F-configuration)
8. [Troubleshooting](#-troubleshooting)
9. [Development & Contributing](#-development--contributing)

---

## 🚀 Quick Start

1. Add to your Gemfile:
```ruby
gem 'actify'
```

2. Install and setup:
```bash
bundle install
rails generate actify:install
```

3. Add to your model:
```ruby
class Post < ApplicationRecord
  include Actify
  has_many :action_logs, as: :actionable

  action :publish, label: "Publish a post" do
    show? do |object, context|
      # Write your logic to determine if the action should be shown
      false
    end

    authorized? do |object, context|
      # Write your logic to determine if the user is authorized to perform the action
      true
    end

    commitable? do |object, context|
      # Write your logic to determine if the action can be committed
      true
    end
    commit do |object, context|
      post.update(published: true)
    end
  end
end
```

4. Use it:
```ruby
post = Post.find(1)
Post::Actions[:publish].commit!(post, Actify::Context.new(actor: current_user))
```

---

## 📖 Basic Concepts

### What's an Action?

An action is a piece of business logic that:
- Has a specific purpose (like "approve" or "publish")
- Can be allowed or denied
- Keeps track of who did it
- Can have specific conditions

Think of actions like special methods that:
- Always know who's trying to use them
- Can say "no" if conditions aren't right
- Remember when they were used and by whom

### Core Components

1. **Action Definition**
   - The rules and logic for your action
   - Lives in your model class

2. **Context**
   - Who's performing the action
   - Any extra data needed

3. **Action Log**
   - Record of what happened
   - Stored in database

---

## 📥 Installation

1. In your Gemfile:
```ruby
gem 'actify'
```

2. Run installer:
```bash
# First install the gem
bundle install

# Then run the installer
rails generate actify:install
```

The installer creates:
- A migration for the action_logs table
- An initializer for configuration

---

## 💡 Simple Example

Let's create a document approval system:

```ruby
class Document < ApplicationRecord
  include Actify
  has_many :action_logs, as: :actionable

  # Define the approve action
  action :approve do
    # Only show this action for draft documents
    show? do |object, context|
      object.status == "draft"
    end

    # Only let reviewers approve
    authorized? do |object, context|
      context.actor.reviewer?
    end

    # Make sure document is complete
    commitable? do |object, context|
      object.title.present? && object.content.present?
    end

    # Do the approval
    commit do |object, context|
      object.update(
        status: "approved",
        approved_at: Time.current,
        approved_by: context.actor.id
      )
    end
  end
end
```

Using the action:
```ruby
document = Document.find(1)

# Create context with the current user
context = Actify::Context.new(
  actor: current_user,
  data: { reason: "Looks good!" }
)

# Execute the action
Document::Actions[:approve].commit!(document, context)
```

---

## 🔄 Advanced Usage

### Action Callbacks

Each action has 4 main callbacks:

| Callback | Question It Answers | Example |
|----------|-------------------|---------|
| `show?` | Should this action be visible? | Show "approve" only for drafts |
| `authorized?` | Can this user do this? | Only reviewers can approve |
| `commitable?` | Is it okay to do this now? | Document must be complete |
| `commit` | What should happen? | Mark as approved and record who did it |

### Using Context

Context lets you pass extra information:

```ruby
context = Actify::Context.new(
  actor: current_user,
  data: {
    reason: "Content verified",
    priority: "high",
    notes: "Urgent approval needed"
  }
)
```

### Checking Action Status

```ruby
action = Document::Actions[:approve]

# Can this user see this action?
action.show?(document, context)

# Are they allowed to do it?
action.authorized?(document, context)

# Can it be done right now?
action.commitable?(document, context)
```

---

## 🔌 Rails Integration

### Simple API Controller

Here's a controller that can handle actions for any model:

```ruby
class ActionsController < ApiController
  before_action :get_object

  def create
    # Find the requested action
    action = @object_class::Actions[params[:action_code].to_sym]
    
    # Set up context with current user
    context = Actify::Context.new(
      actor: current_user,
      data: params[:action_data]
    )
    
    # Try to execute the action
    action_log = action.commit!(@object, context)

    # Return results
    if action_log.finished?
      render json: action_log
    else
      render json: action_log, status: 400
    end
  end

  private

  def get_object
    # Get model name from URL (e.g., /api/documents/123/actions)
    model_name = request.path.split('/')[2].classify
    model_class = model_name.constantize
    
    # Find the specific object
    @object = model_class.find(params[:id])
  end
end
```

### Example API Request

```ruby
# POST /api/documents/123/actions
{
  "action_code": "approve",
  "action_data": {
    "reason": "Looks good",
    "priority": "high"
  }
}
```

---

## 🔧 Troubleshooting

### Common Issues

1. **"Action not found" error**
   ```ruby
   # Check if action exists
   Model::Actions.all                 # List all actions
   Model::Actions[:action_name]       # Look up specific action
   ```

2. **Action won't execute**
   ```ruby
   # Check each condition
   action.show?(object, context)    # Is it visible?
   action.authorized?(object, context) # Is it allowed?
   action.commitable?(object, context) # Can it be done?
   ```

3. **No logs being created**
   ```ruby
   # Make sure model has:
   has_many :action_logs, as: :actionable
   ```

---

## 🛠 Development & Contributing

### Local Setup

1. Clone the repo:
```bash
git clone https://github.com/nguyenta99/actify.git
cd actify
```

2. Setup:
```bash
bin/setup
```

3. Run tests:
```bash
rake spec
```

### Contributing

1. Fork it
2. Create your branch (`git checkout -b feature/awesome`)
3. Commit changes (`git commit -am 'Add awesome'`)
4. Push (`git push origin feature/awesome`)
5. Create Pull Request

---

## 📄 License

Released under the [MIT License](https://opensource.org/licenses/MIT).

---
Built with ❤️ by [nguyenta99](https://github.com/nguyenta99)
