defmodule PubsubChat.RoomManager do
  @moduledoc """
  Manages the creation of chat rooms.

  Rooms are created as supervised processes under `PubsubChat.RoomSupervisor`.
  """

  @doc """
  Creates a new chat room with the given name.

  Returns `{:ok, pid}` if the room was created successfully,
  or `{:error, {:already_started, pid}}` if a room with that name exists.

  ## Examples

      iex> {:ok, pid} = PubsubChat.RoomManager.create_room("lobby")
      iex> is_pid(pid)
      true

      iex> {:ok, _} = PubsubChat.RoomManager.create_room("test_room")
      iex> {:error, {:already_started, _}} = PubsubChat.RoomManager.create_room("test_room")

  """
  def create_room(name) do
    DynamicSupervisor.start_child(
      PubsubChat.RoomSupervisor,
      {PubsubChat.Room, name}
    )
  end
end
