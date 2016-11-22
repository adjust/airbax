Logger.configure(level: :info)
Application.ensure_all_started(:hackney)
Application.ensure_all_started(:sidejob)
ExUnit.start()

defmodule ExUnit.AirbaxCase do
  use ExUnit.CaseTemplate

  using(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  def start_airbax_client() do
    Airbax.Client.start_link()
  end

  def ensure_airbax_client_down(pid) do
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    end
  end

  def capture_log(fun) do
    ExUnit.CaptureIO.capture_io(:user, fn ->
      fun.()
      :timer.sleep(200)
      Logger.flush()
    end)
  end
end

defmodule RollbarAPI do
  alias Plug.Conn
  alias Plug.Adapters.Cowboy

  import Conn

  def start(pid) do
    Cowboy.http(__MODULE__, [test: pid], port: 4004)
  end

  def stop() do
    :timer.sleep(100)
    Cowboy.shutdown(__MODULE__.HTTP)
    :timer.sleep(100)
  end

  def init(opts) do
    Keyword.fetch!(opts, :test)
  end

  def call(%Conn{method: "POST"} = conn, test) do
    {:ok, body, conn} = read_body(conn)
    :timer.sleep(30)
    send test, {:api_request, body}

    body_json =Poison.decode!(body)
    sleep_t = get_in(body_json, ["params", "sleep"])

    if is_integer(sleep_t) && sleep_t > 0 do
      Process.sleep(sleep_t)
    end

    if get_in(body_json, ["params", "return_error?"]) do
      send_resp(conn, 400, ~s({"err": 1, "message": "that was a bad request"}))
    else
      send_resp(conn, 201, "{}")
    end
  end

  def call(conn, _test) do
    send_resp(conn, 404, "Not Found")
  end
end
