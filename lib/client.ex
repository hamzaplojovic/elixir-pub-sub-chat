defmodule PubsubChat.Client do
  @moduledoc """
  Interactive CLI chat client.

  Connects to a room and provides an interactive stdin-based interface
  for sending and receiving messages.

  ## Commands

  - `/quit` - Leave the room and exit
  - `/help` - Show available commands

  ## Example

      PubsubChat.Client.start("lobby", "alice")
      # >>> Joined lobby as alice
      # > hello everyone
      # [alice] hello everyone

  Note: This client works best when run via `mix chat <room> <nickname>`
  rather than directly in iex, due to stdin handling.
  """
  use GenServer

  @doc """
  Starts an interactive chat client.

  Creates the room if it doesn't exist, joins it, and begins
  reading from stdin for user input.
  """
  def start(room_name, nickname) do
    GenServer.start(__MODULE__, {room_name, nickname})
  end

  @doc """
  Stops the chat client.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server callbacks
  @doc false
  def init({room_name, nickname}) do
    # Ensure room exists
    case PubsubChat.RoomManager.create_room(room_name) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Join the room
    PubsubChat.Room.join(room_name, self(), nickname)

    state = %{
      room: room_name,
      nickname: nickname,
      reader_pid: nil
    }

    {:ok, state, {:continue, :start_reader}}
  end

  def handle_continue(:start_reader, state) do
    client_pid = self()
    reader_pid = spawn_link(fn -> read_loop(client_pid) end)
    {:noreply, %{state | reader_pid: reader_pid}}
  end

  def handle_info({:joined, room}, state) do
    IO.puts("\n>>> Joined #{room} as #{state.nickname}")
    print_prompt()
    {:noreply, state}
  end

  def handle_info({:left, room}, state) do
    IO.puts("\n>>> Left #{room}. Goodbye!")
    {:stop, :normal, state}
  end

  def handle_info({:user_joined, _room, nickname}, state) do
    IO.puts("\n>>> #{nickname} joined")
    print_prompt()
    {:noreply, state}
  end

  def handle_info({:user_left, _room, nickname}, state) do
    IO.puts("\n>>> #{nickname} left")
    print_prompt()
    {:noreply, state}
  end

  def handle_info({:new_message, _room, nickname, message}, state) do
    IO.puts("\n[#{nickname}] #{message}")
    print_prompt()
    {:noreply, state}
  end

  def handle_info({:input, "/quit"}, state) do
    PubsubChat.Room.leave(state.room, self())
    {:noreply, state}
  end

  def handle_info({:input, "/help"}, state) do
    IO.puts("""
    
    Commands:
      /quit  - Leave the room and exit
      /help  - Show this help message
    """)
    print_prompt()
    {:noreply, state}
  end

  def handle_info({:input, ""}, state) do
    print_prompt()
    {:noreply, state}
  end

  def handle_info({:input, message}, state) do
    PubsubChat.Room.send_message(state.room, self(), message)
    {:noreply, state}
  end

  def terminate(_reason, state) do
    if state.reader_pid && Process.alive?(state.reader_pid) do
      Process.exit(state.reader_pid, :kill)
    end
    :ok
  end

  # Input reader loop (runs in separate process)
  defp read_loop(client_pid) do
    case IO.gets("") do
      :eof ->
        send(client_pid, {:input, "/quit"})

      {:error, _} ->
        send(client_pid, {:input, "/quit"})

      line ->
        input = String.trim(line)
        send(client_pid, {:input, input})
        read_loop(client_pid)
    end
  end

  defp print_prompt do
    IO.write("> ")
  end
end
