# Using Airbax in Plug-based applications

[Plug](https://github.com/elixir-lang/plug) provides the `Plug.ErrorHandler` plug which plays very well with Airbax. As you can see in [the documentation for `Plug.ErrorHandler`](https://hexdocs.pm/plug/Plug.ErrorHandler.html), this plug can be used to "catch" exceptions that happen inside a given plug and act on them. This can be used to report all exceptions happening in that plug to Airbrake/Errbit. For example:

```elixir
defmodule MyApp.Router do
  use Plug.Router # or `use MyApp.Web, :router` for Phoenix apps
  use Plug.ErrorHandler

  defp handle_errors(conn, %{reason: reason, stack: stacktrace}) do
    Airbax.report(reason, stacktrace)
  end
end
```

Airbax also supports attaching *metadata* to a reported exception. For example, in the code snippet above, we could report the request parameters as metadata to be attached to the exception:

```elixir
defp handle_errors(conn, %{reason: reason, stack: stacktrace}) do
  Airbax.report(reason, stacktrace, %{params: conn.params})
end
```

It's possible to attach a lot of data as additional parameters. To add more data about the request to the exception reported in the snippet above, you could do something like this:

```elixir
defp handle_errors(conn, %{reason: reason, stack: stacktrace}) do
  conn =
    conn
    |> Plug.Conn.fetch_cookies()
    |> Plug.Conn.fetch_query_params()

  conn_data = %{
    "cookies" => conn.req_cookies,
    "url" => "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}",
    "user_ip" => (conn.remote_ip |> Tuple.to_list() |> Enum.join(".")),
    "headers" => Enum.into(conn.req_headers, %{}),
    "params" => conn.params,
    "method" => conn.method,
  }

  Airbax.report(reason, stacktrace, conn_data)
end
```
