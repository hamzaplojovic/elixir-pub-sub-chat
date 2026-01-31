defmodule PubsubChat.RoomTest do
  use ExUnit.Case, async: true

  setup do
    room_name = "test_room_#{System.unique_integer([:positive])}"
    {:ok, pid} = PubsubChat.RoomManager.create_room(room_name)
    {:ok, room: room_name, room_pid: pid}
  end

  describe "join/3" do
    test "sends :joined message to user", %{room: room} do
      PubsubChat.Room.join(room, self(), "alice")
      assert_receive {:joined, ^room}
    end

    test "broadcasts :user_joined to existing users", %{room: room} do
      PubsubChat.Room.join(room, self(), "alice")
      assert_receive {:joined, _}

      # Spawn another "user"
      test_pid = self()
      spawn(fn ->
        PubsubChat.Room.join(room, self(), "bob")
        # Forward the joined message back to test process
        receive do
          msg -> send(test_pid, {:bob_received, msg})
        end
      end)

      # Alice should receive bob joined
      assert_receive {:user_joined, ^room, "bob"}
    end
  end

  describe "leave/2" do
    test "sends :left message to user", %{room: room} do
      PubsubChat.Room.join(room, self(), "alice")
      assert_receive {:joined, _}

      PubsubChat.Room.leave(room, self())
      assert_receive {:left, ^room}
    end

    test "broadcasts :user_left to remaining users", %{room: room} do
      PubsubChat.Room.join(room, self(), "alice")
      assert_receive {:joined, _}

      other_pid = spawn(fn ->
        receive do
          _ -> :ok
        end
      end)

      PubsubChat.Room.join(room, other_pid, "bob")
      assert_receive {:user_joined, _, "bob"}

      PubsubChat.Room.leave(room, other_pid)
      assert_receive {:user_left, ^room, "bob"}
    end

    test "does nothing for non-member", %{room: room} do
      # Should not crash
      PubsubChat.Room.leave(room, self())
      refute_receive {:left, _}
    end
  end

  describe "send_message/3" do
    test "broadcasts message to all users", %{room: room} do
      PubsubChat.Room.join(room, self(), "alice")
      assert_receive {:joined, _}

      PubsubChat.Room.send_message(room, self(), "hello world")
      assert_receive {:new_message, ^room, "alice", "hello world"}
    end

    test "includes sender's nickname in broadcast", %{room: room} do
      PubsubChat.Room.join(room, self(), "bob")
      assert_receive {:joined, _}

      PubsubChat.Room.send_message(room, self(), "test message")
      assert_receive {:new_message, _, "bob", "test message"}
    end
  end
end

defmodule PubsubChat.RoomManagerTest do
  use ExUnit.Case, async: true

  describe "create_room/1" do
    test "creates a new room" do
      room_name = "manager_test_#{System.unique_integer([:positive])}"
      assert {:ok, pid} = PubsubChat.RoomManager.create_room(room_name)
      assert is_pid(pid)
    end

    test "returns error for duplicate room" do
      room_name = "duplicate_test_#{System.unique_integer([:positive])}"
      {:ok, pid} = PubsubChat.RoomManager.create_room(room_name)
      assert {:error, {:already_started, ^pid}} = PubsubChat.RoomManager.create_room(room_name)
    end
  end
end
