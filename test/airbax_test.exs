defmodule AirbaxTest do
  use ExUnit.AirbaxCase

  setup do
    {:ok, _} = RollbarAPI.start(self())
    on_exit(&RollbarAPI.stop/0)
  end

  test "report/3 with an error" do
    stacktrace = [{Test, :report, 2, [file: 'file.exs', line: 16]}]
    exception = RuntimeError.exception("pass")
    :ok = Airbax.report(:error, exception, stacktrace, %{}, %{uuid: "d4c7"})
    assert_receive {:api_request, body}
    assert body =~ ~s("type":"RuntimeError")
    assert body =~ ~s("message":"pass")
    assert body =~ ~s("file":"file.exs")
    assert body =~ ~s("line":16)
    assert body =~ ~s("function":"Test.report/2")
    assert body =~ ~s("uuid":"d4c7")
  end

  test "report/3 with an exit" do
    stacktrace = [{Test, :report, 2, [file: 'file.exs', line: 16]}]
    :ok = Airbax.report(:exit, :oops, stacktrace)
    assert_receive {:api_request, body}
    assert body =~ ~s("type":"exit")
    assert body =~ ~s("message":":oops")
    assert body =~ ~s("file":"file.exs")
    assert body =~ ~s("line":16)
    assert body =~ ~s("function":"Test.report/2")
  end

  test "report/3 with a throw" do
    stacktrace = [{Test, :report, 2, [file: 'file.exs', line: 16]}]
    :ok = Airbax.report(:throw, :oops, stacktrace)
    assert_receive {:api_request, body}
    assert body =~ ~s("type":"throw")
    assert body =~ ~s("message":":oops")
    assert body =~ ~s("file":"file.exs")
    assert body =~ ~s("line":16)
    assert body =~ ~s("function":"Test.report/2")
  end
end
