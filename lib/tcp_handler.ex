defmodule PubsubChat.TcpHandler do
  @moduledoc """
  Handles a single TCP client connection.

  Manages the client lifecycle:
  1. Prompts for nickname
  2. Prompts for room name
  3. Joins the room and relays messages

  ## Commands

  - `/quit` - Leave the room and disconnect
  - `/help` - Show available commands
  """
  use GenServer

  @doc false
  def start(socket) do
    GenServer.start(__MODULE__, socket)
  end

  def init(socket) do
    :inet.setopts(socket, active: true)
    send_line(socket, "Welcome to PubsubChat!")
    send_line(socket, "Enter your nickname:")

    {:ok, %{socket: socket, nickname: nil, room: nil}}
  end

  # TCP messages
  def handle_info({:tcp, _socket, data}, %{nickname: nil} = state) do
    nickname = String.trim(data)
    send_line(state.socket, "Hello #{nickname}! Enter room name to join:")
    {:noreply, %{state | nickname: nickname}}
  end

  def handle_info({:tcp, _socket, data}, %{room: nil} = state) do
    room_name = String.trim(data)

    case PubsubChat.RoomManager.create_room(room_name) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    PubsubChat.Room.join(room_name, self(), state.nickname)
    {:noreply, %{state | room: room_name}}
  end

  def handle_info({:tcp, _socket, data}, state) do
    message = String.trim(data)

    case message do
      "/quit" ->
        PubsubChat.Room.leave(state.room, self())
        {:noreply, state}

      "/help" ->
        send_line(state.socket, "Commands: /quit - leave room, /help - show this")
        {:noreply, state}

      "" ->
        {:noreply, state}

      _ ->
        PubsubChat.Room.send_message(state.room, self(), message)
        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, state) do
    if state.room do
      PubsubChat.Room.leave(state.room, self())
    end
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _socket, _reason}, state) do
    {:stop, :normal, state}
  end

  # Room messages
  def handle_info({:joined, room}, state) do
    send_line(state.socket, ">>> Joined #{room}")
    {:noreply, state}
  end

  def handle_info({:left, room}, state) do
    send_line(state.socket, ">>> Left #{room}. Goodbye!")
    :gen_tcp.close(state.socket)
    {:stop, :normal, state}
  end

  def handle_info({:user_joined, _room, nickname}, state) do
    send_line(state.socket, ">>> #{nickname} joined")
    {:noreply, state}
  end

  def handle_info({:user_left, _room, nickname}, state) do
    send_line(state.socket, ">>> #{nickname} left")
    {:noreply, state}
  end

  def handle_info({:new_message, _room, nickname, message}, state) do
    send_line(state.socket, "[#{nickname}] #{message}")
    {:noreply, state}
  end

  defp send_line(socket, text) do
    :gen_tcp.send(socket, text <> "\n")
  end
end
