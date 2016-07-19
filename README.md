# Airbax

Elixir client for [Airbrake](https://airbrake.io).

Airbax is a clone of awesome [Rollbax](https://github.com/elixir-addicts/rollbax), but for Airbrake/Errbit.

Airbax was made by simply replacing 'rollbax' with 'airbax' everywhere in the code, changing
`Rollbax.Item` and `Rollbax.Client` to make them compatible with Airbrake API specifications
and fixing some tests. That's it.  
All credits go to Rollbax.

## Installation

Add Airbax as a dependency to your `mix.exs` file:

```elixir
defp deps() do
  [{:airbax, "~> 0.0.2"}]
end
```

and add it to your list of applications:

```elixir
def application() do
  [applications: [:airbax]]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

## Usage

Airbax requires some configuration in order to work. For example, in `config/config.exs`:

```elixir
config :airbax,
  project_key: "ffb8056a621f309eeb1ed87fa0c7",
  project_id: true,
  environment: "production"
```

If you're using Errbit, add to the configuration above an URL of your Errbit service as `url` parameter.  

Then, exceptions (errors, exits, and throws) can be reported to Airbrake or Errbit using `Airbax.report/3`:

```elixir
try do
  DoesNotExist.for_sure()
rescue
  exception ->
    Airbax.report(:error, exception, System.stacktrace())
end
```

### Plug and Phoenix

For examples on how to take advantage of Airbax in Plug-based applications (including Phoenix applications), have a look at the ["Using Airbax in Plug-based applications" page in the documentation](http://hexdocs.pm/airbax/using-airbax-in-plug-based-applications.html).  

### Non-production reporting

For non-production environments error reporting can be either disabled completely (by setting `:enabled` to `false`) or replaced with logging of exceptions (by setting `:enabled` to `:log`).

```elixir
config :airbax, enabled: :log
```

## License

This software is licensed under [the ISC license](LICENSE).
