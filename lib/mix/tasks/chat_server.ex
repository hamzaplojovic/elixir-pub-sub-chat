defmodule Mix.Tasks.Chat.Server do
  use Mix.Task

  @shortdoc "Start the chat server"

  def run(args) do
    port = case args do
      [port_str] -> String.to_integer(port_str)
      _ -> 4000
    end

    Mix.Task.run("app.start")
    {:ok, _} = PubsubChat.TcpServer.start_link(port: port)

    IO.puts("Chat server running on port #{port}")
    IO.puts("Connect with: nc localhost #{port}")
    IO.puts("Or: telnet localhost #{port}")
    IO.puts("Press Ctrl+C to stop")

    Process.sleep(:infinity)
  end
end
