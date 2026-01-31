defmodule PubsubChat.TcpServer do
  @moduledoc """
  TCP server that accepts chat client connections.

  Listens on a configurable port (default 4000) and spawns a
  `PubsubChat.TcpHandler` for each connected client.

  ## Usage

      # Start server on default port 4000
      PubsubChat.TcpServer.start_link()

      # Start server on custom port
      PubsubChat.TcpServer.start_link(port: 5000)

  Clients can connect using netcat or telnet:

      nc localhost 4000
      telnet localhost 4000
  """
  use GenServer
  require Logger

  @port 4000

  @doc """
  Starts the TCP server.

  ## Options

  - `:port` - Port to listen on (default: 4000)
  """
  def start_link(opts \\ []) do
    port = Keyword.get(opts, :port, @port)
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    {:ok, listen_socket} = :gen_tcp.listen(port, [
      :binary,
      packet: :line,
      active: false,
      reuseaddr: true
    ])

    Logger.info("Chat server listening on port #{port}")
    send(self(), :accept)
    {:ok, %{listen_socket: listen_socket, port: port}}
  end

  def handle_info(:accept, state) do
    {:ok, client_socket} = :gen_tcp.accept(state.listen_socket)
    {:ok, handler_pid} = PubsubChat.TcpHandler.start(client_socket)
    :gen_tcp.controlling_process(client_socket, handler_pid)
    send(self(), :accept)
    {:noreply, state}
  end
end
