defmodule Airbax.Client do
  @moduledoc false

  # This GenServer keeps a pre-built bare-bones version of an exception (a
  # "draft") to be reported to Airbrake, which is then filled with the data
  # related to each specific exception when such exception is being
  # reported. This GenServer is also responsible for actually sending data to
  # the Airbrake API and receiving responses from said API.

  use GenServer

  require Logger

  alias Airbax.Item

  @default_url "https://airbrake.io"
  @headers [{"content-type", "application/json"}]

  defmodule Regname do
    # this module is needed because it'll be "rewritten" by sidejob
  end

  ## GenServer state

  defstruct [:draft, :url, :enabled, hackney_responses: %{}]

  ## Public API

  def start_sidejob_resource() do
    limit = get_config(:overload_threshold, 500)
    :sidejob.new_resource(__MODULE__.Regname, __MODULE__, limit)
  end

  def emit(level, body, params, session) do
    event = {Atom.to_string(level), body, params, session}
    try do :sidejob.cast(__MODULE__.Regname, {:emit, event})
    rescue ErlangError ->
      Logger.warn("(Airbax) Trying to report an exception but the :airbax application has not been started")
    end
  end

  def default_url do
    @default_url
  end

  ## GenServer callbacks

  def init(_) do
    enabled = get_config(:enabled, true)
    project_key = fetch_config(:project_key)
    project_id = fetch_config(:project_id)
    envt = fetch_config(:environment)
    url = get_config(:url, Airbax.Client.default_url)

    Logger.metadata(airbax: false)
    :ok = :hackney_pool.start_pool(__MODULE__, [max_connections: 20])
    {:ok, new(project_key, project_id, envt, url, enabled)}
  end

  def terminate(_reason, _state) do
    :ok = :hackney_pool.stop_pool(__MODULE__)
  end

  def handle_cast({:emit, _event}, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_cast({:emit, event}, %{enabled: :log} = state) do
    {level, body, params, session} = event
    Logger.info [
      "(Airbax) registered report:", ?\n, inspect(body),
      "\n         Level: ", level,
      "\n Custom params: ", inspect(params),
      "\n  Session data: ", inspect(session),
    ]
    {:noreply, state}
  end

  def handle_cast({:emit, event}, %{enabled: true} = state) do
    payload = compose_json(state.draft, event)
    opts = [:async, pool: __MODULE__]
    case :hackney.post(state.url, @headers, payload, opts) do
      {:ok, _ref} -> :ok
      {:error, reason} ->
        Logger.error("(Airbax) connection error: #{inspect(reason)}")
    end
    {:noreply, state}
  end

  def handle_info({:hackney_response, ref, response}, state) do
    new_state = handle_hackney_response(ref, response, state)
    {:noreply, new_state}
  end

  def handle_info(message, state) do
    Logger.info("(Airbax) unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  ## Helper functions

  defp new(project_key, project_id, environment, url, enabled) do
    draft = Item.draft(environment)
    url = build_url(project_key, project_id, url)

    %__MODULE__{draft: draft, url: url, enabled: enabled}
  end

  defp build_url(project_key, project_id, url) do
    "#{url}/api/v3/projects/#{project_id}/notices?key=#{project_key}"
  end

  defp compose_json(draft, event) do
    Item.compose(draft, event)
    |> Poison.encode!(iodata: true)
  end

  defp handle_hackney_response(ref, :done, %{hackney_responses: responses} = state) do
    body = responses |> Map.fetch!(ref) |> IO.iodata_to_binary()

    case Poison.decode(body) do
      {:ok, %{"err" => 1, "message" => message}} when is_binary(message) ->
        Logger.error("(Airbax) API returned an error: #{inspect message}")
      {:ok, response} ->
        Logger.debug("(Airbax) API response: #{inspect response}")
      {:error, _} ->
        Logger.error("(Airbax) API returned malformed JSON: #{inspect body}")
    end

    %{state | hackney_responses: Map.delete(responses, ref)}
  end

  defp handle_hackney_response(ref, {:status, code, description}, %{hackney_responses: responses} = state) do
    if code != 201 do
      Logger.error("(Airbax) unexpected API status: #{code}/#{description}")
    end

    %{state | hackney_responses: Map.put(responses, ref, [])}
  end

  defp handle_hackney_response(_ref, {:headers, headers}, state) do
    Logger.debug("(Airbax) API headers: #{inspect(headers)}")
    state
  end

  defp handle_hackney_response(ref, body_chunk, %{hackney_responses: responses} = state)
  when is_binary(body_chunk) do
    %{state | hackney_responses: Map.update!(responses, ref, &[&1 | body_chunk])}
  end

  defp handle_hackney_response(ref, {:error, reason}, %{hackney_responses: responses} = state) do
    Logger.error("(Airbax) connection error: #{inspect(reason)}")
    %{state | hackney_responses: Map.delete(responses, ref)}
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
