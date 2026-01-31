defmodule PubsubChat.Room do
  @moduledoc """
  A chat room process that manages users and broadcasts messages.

  Each room is a GenServer that maintains a map of connected users
  (pid -> nickname) and handles message broadcasting.

  ## Messages sent to users

  - `{:joined, room_name}` - Sent to a user when they successfully join
  - `{:left, room_name}` - Sent to a user when they leave
  - `{:user_joined, room_name, nickname}` - Broadcast when someone joins
  - `{:user_left, room_name, nickname}` - Broadcast when someone leaves
  - `{:new_message, room_name, nickname, message}` - Broadcast for chat messages
  """
  use GenServer

  @doc """
  Starts a new room process with the given name.

  The room is registered via `PubsubChat.Registry` for name-based lookups.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, %{name: name, users: %{}}, name: via_tuple(name))
  end

  @doc """
  Joins a user to the room.

  Sends `{:joined, room_name}` to the joining user and broadcasts
  `{:user_joined, room_name, nickname}` to existing users.
  """
  def join(room_name, user_pid, nickname) do
    GenServer.cast(via_tuple(room_name), {:join, user_pid, nickname})
  end

  @doc """
  Removes a user from the room.

  Sends `{:left, room_name}` to the leaving user and broadcasts
  `{:user_left, room_name, nickname}` to remaining users.
  """
  def leave(room_name, user_pid) do
    GenServer.cast(via_tuple(room_name), {:leave, user_pid})
  end

  @doc """
  Sends a message to all users in the room.

  Broadcasts `{:new_message, room_name, nickname, message}` to all users,
  including the sender.
  """
  def send_message(room_name, user_pid, message) do
    GenServer.cast(via_tuple(room_name), {:message, user_pid, message})
  end

  # Internal
  defp via_tuple(name) do
    {:via, Registry, {PubsubChat.Registry, name}}
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:join, user_pid, nickname}, state) do
    new_state = %{state | users: Map.put(state.users, user_pid, nickname)}
    broadcast(state.users, {:user_joined, state.name, nickname})
    send(user_pid, {:joined, state.name})
    {:noreply, new_state}
  end

  def handle_cast({:leave, user_pid}, state) do
    case Map.pop(state.users, user_pid) do
      {nil, _} ->
        {:noreply, state}

      {nickname, remaining_users} ->
        broadcast(remaining_users, {:user_left, state.name, nickname})
        send(user_pid, {:left, state.name})
        {:noreply, %{state | users: remaining_users}}
    end
  end

  def handle_cast({:message, user_pid, message}, state) do
    nickname = Map.get(state.users, user_pid, "unknown")
    broadcast(state.users, {:new_message, state.name, nickname, message})
    {:noreply, state}
  end

  defp broadcast(users, message) do
    Enum.each(users, fn {pid, _nickname} ->
      send(pid, message)
    end)
  end
end
