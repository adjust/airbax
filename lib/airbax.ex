defmodule Airbax do
  @moduledoc """
  This module provides functions to report any kind of exception to
  [Airbrake](https://airbrake.io) or Errbit.

  ## Configuration

  The `:airbax` application needs to be configured properly in order to
  work. This configuration can be done, for example, in `config/config.exs`:

      config :airbax,
        project_key: "9309123491",
        project_id: true,
        environment: "production"
  """

  use Application

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec

    enabled = get_config(:enabled, true)

    project_key = fetch_config(:project_key)
    project_id = fetch_config(:project_id)
    envt  = fetch_config(:environment)
    url = get_config(:url, Airbax.Client.default_url)

    children = [
      worker(Airbax.Client, [project_key, project_id, envt, enabled, url])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Reports the given error/exit/throw.

  `kind` specifies the kind of exception being reported while `value` specifies
  the value of that exception. `kind` can be:

    * `:error` - reports an exception defined with `defexception`; `value` must
      be an exception, or this function will raise an `ArgumentError` exception
    * `:exit` - reports an exit; `value` can be any term
    * `:throw` - reports a thrown term; `value` can be any term

  `kind` itself is not sent to the Airbrake/Errbit, it's only used to
  properly parse `value`.

  The `params` and `session` arguments can be used to customize metadata
  sent to Airbrake.

  This function is *fire-and-forget*: it will always return `:ok` right away and
  perform the reporting of the given exception in the background.

  ## Examples

  Exceptions can be reported directly:

      Airbax.report(:error, ArgumentError.exception("oops"), System.stacktrace())
      #=> :ok

  Often, you'll want to report something you either rescued or caught. For
  rescued exceptions:

      try do
        raise ArgumentError, "oops"
      rescue
        exception ->
          Airbax.report(:error, exception, System.stacktrace())
          # You can also reraise the exception here with reraise/2
      end

  For caught exceptions:

      try do
        throw(:oops)
        # or exit(:oops)
      catch
        kind, value ->
          Airbax.report(kind, value, System.stacktrace())
      end

  Using custom data:

      Airbax.report(:exit, :oops, System.stacktrace(), %{"weather" => "rainy"})

  """
  @spec report(:error | :exit | :throw, any, [any], map, map) :: :ok
  def report(kind, value, stacktrace, params \\ %{}, session \\ %{})
  when kind in [:error, :exit, :throw] and is_list(stacktrace) and is_map(params) and is_map(session) do
    # We need this manual check here otherwise Exception.format_banner(:error,
    # term) will assume that term is an Erlang error (it will say
    # "** # (ErlangError) ...").
    if kind == :error and not Exception.exception?(value) do
      raise ArgumentError, "expected an exception when the kind is :error, got: #{value}"
    end

    body = Airbax.Item.exception_to_body(kind, value, stacktrace)
    Airbax.Client.emit(:error, body, params, session)
  end

  defp get_config(key, default) do
    Application.get_env(:airbax, key, default)
  end

  defp fetch_config(key) do
    case get_config(key, :not_found) do
      :not_found ->
        raise ArgumentError, "the configuration parameter #{inspect(key)} is not set"
      value -> value
    end
  end
end
