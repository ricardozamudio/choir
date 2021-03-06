defmodule Choir.VoiceChannel do
  use Phoenix.Channel
  require Logger

  # When a new client connects to the socket just send back :ok. Some data needs
  # to be gathered and sent to the server which will be handled in the "connect"
  # message handler.
  def join("voices", _message, socket) do
    Logger.debug "joining voices"
    {:ok, socket}
  end

  @doc """
  When a client connects insert their data into the ETS map and then update the
  the aggregate data. Then send a broadcast out to all clients with the new
  aggregate data.
  """
  def handle_in("connect", client_map, socket) do
    Logger.debug "handle_in:connect"
    client_data = Choir.ClientData.new(client_map)

    Choir.ClientTableServer.insert(socket, client_data)
    updated_voice_data = Choir.AggDataServer.add_data(client_data)

    broadcast! socket, "voice_update", updated_voice_data
    {:noreply, socket}
  end

  @doc """
  When a client's data changes update their data in the ETS map and update the
  aggregate data.
  """
  def handle_in("voice_update", new_map, socket) do
    Logger.debug "handle_in:voice_update"
    new_data = Choir.ClientData.new(new_map)

    updated_voice_data = Choir.AggDataServer.update_data(socket, new_data)
    broadcast! socket, "voice_update", updated_voice_data
    {:noreply, socket}
  end

  @doc """
  A voice update signifies that new data has been added to the aggregate data.
  The clients need to be notified of this data change so they can alter their
  sound accordingly.
  """
  def handle_out("voice_update", payload, socket) do
    Logger.debug "handle_out:voice_update"

    push socket, "voice_update", payload
    {:noreply, socket}
  end

  @doc """
  When `socket` is terminated (closed, disconnected, left) remove them from the
  ETS map and remove their data from the aggregate data. Then broadcast out to
  all clients with the new aggregate data.
  """
  def terminate(_reason, socket) do
    Logger.debug "terminating connection"

    case Choir.ClientTableServer.lookup(socket) do
      {:ok, client_data} ->
        Choir.ClientTableServer.delete(socket)
        updated_voice_data = Choir.AggDataServer.remove_data(client_data)

        broadcast! socket, "voice_update", updated_voice_data
        {:noreply, socket}  
      :error ->
        IO.puts :stderr, "The socket was not found in the ETS table."
        {:noreply, socket}
    end
  end
end
