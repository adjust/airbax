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

  ## GenServer state

  defstruct [:draft, :url, :enabled, hackney_opts: [], hackney_responses: %{}]

  ## Public API

  def start_link(project_key, project_id, environment, enabled, url, hackney_opts) do
    state = new(project_key, project_id, environment, enabled, url, hackney_opts)
    GenServer.start_link(__MODULE__, state, [name: __MODULE__])
  end

  def emit(level, body, params, session) do
    if pid = Process.whereis(__MODULE__) do
      event = {Atom.to_string(level), body, params, session}
      GenServer.cast(pid, {:emit, event})
    else
      Logger.warn("(Airbax) Trying to report an exception but the :airbax application has not been started")
    end
  end

  def default_url do
    @default_url
  end

  ## GenServer callbacks

  def init(state) do
    Logger.metadata(airbax: false)
    :ok = :hackney_pool.start_pool(__MODULE__, [max_connections: 20])
    {:ok, state}
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

  def handle_cast({:emit, event}, %{enabled: true, hackney_opts: hackney_opts} = state) do
    payload = compose_json(state.draft, event)
    opts = [:async, {:pool, __MODULE__} | hackney_opts]

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

  defp new(project_key, project_id, environment, enabled, url, hackney_opts) do
    draft = Item.draft(environment)
    url = build_url(project_key, project_id, url)

    %__MODULE__{draft: draft, url: url, hackney_opts: hackney_opts, enabled: enabled}
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
end
