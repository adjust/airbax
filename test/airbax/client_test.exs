defmodule Airbax.ClientTest do
  use ExUnit.AirbaxCase

  alias Airbax.Client

  setup do
    {:ok, _} = RollbarAPI.start(self())
    on_exit(&RollbarAPI.stop/0)
  end

  test "emit/5" do
    :ok = Client.emit(:warn, %{"message" => %{"body" => "pass"}}, _params= %{foo: "bar"}, %{})
    assert_receive {:api_request, body}
    assert body =~ ~s("environment":"test")
    assert body =~ ~s("body":"pass")
    assert body =~ ~s("foo":"bar")
  end

  test "mass sending" do
    for _ <- 1..60 do
      :ok = Client.emit(:error, %{"message" => %{"body" => "pass"}}, %{}, %{})
    end

    for _ <- 1..60 do
      assert_receive {:api_request, _body}
    end
  end

  test "emit slow" do
    n = Application.fetch_env!(:airbax, :overload_threshold) * 10

    sent = Enum.take_while(1..n, fn _ ->
      :ok == Client.emit(:warn, %{},  %{sleep: 50}, %{})
    end)

    assert length(sent) < n

    for _ <- sent do
      assert_receive {:api_request, _body}
    end
  end

  test "endpoint is down" do
    :ok = RollbarAPI.stop
    log = capture_log(fn ->
      :ok = Client.emit(:error, %{"message" => %{"body" => "miss"}}, %{}, %{})
    end)
    assert log =~ "[error] (Airbax) connection error: :econnrefused"
    refute_receive {:api_request, _body}
  end

  test "errors from the API are logged" do
    log = capture_log(fn ->
      :ok = Client.emit(:error, %{}, %{return_error?: true}, %{})
      assert_receive {:api_request, _body}
    end)

    assert log =~ ~s{[error] (Airbax) unexpected API status: 400}
    assert log =~ ~s{[error] (Airbax) API returned an error: "that was a bad request"}
  end
end
