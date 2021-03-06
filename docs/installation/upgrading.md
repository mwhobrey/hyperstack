# Upgrading from legacy Hyperloop

This guide sets out to provide the steps necessary to move an existing project from legacy Hyperloop to Hyperstack. There are a number of changes which need to be considered.

## Summary of changes

+ Creating a new Hyperstack Rails application
+ New Hyperstack gems
+ Renamed folders
+ Hyperstack configuration
+ Hyperloop classes have been renamed Hyperstack
+ There is a new concept of a base `HyperComponent` and `HyperStore` base class
+ State syntax has changed
+ Param syntax has changed
+ The Router DSL has changed slightly

## Creating a new Hyperstack Rails application

In Hyperstack we are using Rails templates to create new applications.

+ Follow these instructions: https://github.com/hyperstack-org/hyperstack/tree/edge/install
+ See the template for an understanding of the installation steps: https://github.com/hyperstack-org/hyperstack/blob/edge/install/rails-webpacker.rb

**If you are not upgrading an existing Hyoperloop application, you do not need to follow the rest of these instructions.**

## Hyperstack gem

Hyperstack (with Rails) requires just one Gem:

```ruby
# gem 'webpacker' # if you are using webpacker
gem 'rails-hyperstack'
```

Delete all Hyperloop gems from your gemfile and do a `bundle update`.

## Renamed folders

+ `app/hyperloop` has become `app/hyperstack`
+ The sub-folder structure has not changed (components, models, stores, etc)

## Hyperstack configuration

+ `config/initializers/hyperloop.rb` has been renamed `config/initializers/hyperstack.rb`

The configuration initialiser has changed a little. Please see this page for details: https://github.com/hyperstack-org/hyperstack/blob/edge/docs/installation/config.md

## Hyperloop classes have been renamed Hyperstack

In all cases, `Hyperloop` has been replaced with `Hyperstack`. For example:

In Hyperloop:

```ruby
Hyperloop::Application.acting_user_id
```
In Hyperstack becomes:

```ruby
Hyperstack::Application.acting_user_id
```

The simplest way to implement this change is a global search and replace in your project.

## There is a new concept of a base HyperComponent and HyperStore base class

In Hyperloop, all Components and Stores inherited from a base `Hyperloop::Component` class. In HyperStack (following the new Rails convention), we do not provide the base class but encourage you to create your own. This is very useful for containing methods that all your Components share.

To implement this change, you need to create your HyperComponent class:

```ruby
class HyperComponent
  include Hyperstack::Component
  include Hyperstack::State::Observable # if you are using state
  include Hyperstack::Router::Helpers # if you are using the router

  def some_shared_method
    # a helper method that all your Component might need
  end
end
```

Then you need to do a search and replace on all your `Hyperloop::Component` classes and replace them with `HyperComponent`. For example:

In Hyperloop:

```ruby
class MyComp < Hyperloop::Component
  render do
    ...
  end
end
```

In Hyperstack becomes:

```ruby
class MyComp < HyperComponent
  render do
    ...
  end
end
```

`HyperComponent` is explained here: https://github.com/hyperstack-org/hyperstack/blob/edge/docs/dsl-client/hyper-component.md#hypercomponent


**The same is true for `Hyperloop::Store` to `HyperStore`**.

You will need to create a `HyperStore` class and make the same changes as above.

Note that in Hyperstack, any ruby class can be a store by merely including the `include Hyperstack::State::Observable` mixin.

For example:

```ruby
class StoresAreUs
  include Hyperstack::State::Observable

  def store_something thing
    mutate @thing = thing # note the new mutate syntax
  end
end
```

## State syntax has changed

In Hyperloop you mutated state like this:

```ruby
mutate.something true
```

In Hyperstack becomes:

```ruby
mutate @something = true
```

You also use reference in a different way:

In Hyperloop:

```ruby
H1 { 'Yay' } if state.something
```

In Hyperstack becomes:

```ruby
H1 { 'Yay' } if @something
```

There are several advantages to this new approach:

+ It is significantly faster (ask Mitch)
+ It feels more natural to think about state variables as normal instance variables
+ You only use the `mutate` method when you want React to re-render based on the change to state. This gives you more control.
+ You can string mutations together. For example:

```ruby
mutate @something = true, @amount = 100, @living = :good
```

You can read more about state here: https://github.com/hyperstack-org/hyperstack/blob/edge/docs/dsl-client/hyper-component.md#state

## Param syntax has changed

The syntax for using params has changed:

In Hyperloop:

```ruby
class SayHello < Hyper::Component
  param :first_name

  render do
    H1 { "Hello #{params.first_name}" }
  end
```

In Hyperstack becomes:

```ruby
class SayHello < HyperComponent
  param :first_name

  render do
    H1 { "Hello #{@FirstName}" } # Note the conversion of snake_case to CamelCase
  end
```

This change has been made to underline that params are immutable. (Though this is not true for Models, but they get the same CamelCase treatment).

You can read more about this here: https://github.com/hyperstack-org/hyperstack/blob/edge/docs/dsl-client/hyper-component.md#params

## The Router DSL has changed slightly

Routers are now normal Components with a render method.

A Hyperstack router looks like this:

```ruby
class MainFrame < HyperComponent
  include Hyperstack::Router # note the inclusion of the Router mixin

  render(DIV) do # note the render method
    Switch do
      Route('/', exact: true, mounts: HomeIndex)
      Route('/app', exact: true, mounts: AppIndex)
    end
  end
end
```
