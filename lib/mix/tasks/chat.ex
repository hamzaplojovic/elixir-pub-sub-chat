defmodule Mix.Tasks.Chat do
  use Mix.Task

  @shortdoc "Start an interactive chat client"

  def run(args) do
    case args do
      [room, nickname] ->
        start_distributed(nickname)
        Mix.Task.run("app.start")
        PubsubChat.Client.start(room, nickname)
        Process.sleep(:infinity)

      _ ->
        IO.puts("Usage: mix chat <room> <nickname>")
        IO.puts("Example: mix chat lobby hamza")
    end
  end

  defp start_distributed(nickname) do
    node_name = :"#{nickname}@127.0.0.1"
    Node.start(node_name, :shortnames)
    Node.set_cookie(:pubsub_chat)
  end
end
