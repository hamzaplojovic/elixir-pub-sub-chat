defmodule PubsubChat.Application do
  @moduledoc """
  The PubsubChat application supervisor.

  Starts the following processes:
  - `PubsubChat.Registry` - Registry for room name lookups
  - `PubsubChat.RoomSupervisor` - DynamicSupervisor for room processes
  """
  use Application

  @doc false
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: PubsubChat.Registry}, # <--- add this
      {DynamicSupervisor, strategy: :one_for_one, name: PubsubChat.RoomSupervisor}
    ]

    opts = [strategy: :one_for_one, name: PubsubChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
