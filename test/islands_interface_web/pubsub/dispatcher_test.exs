defmodule IslandsInterfaceWeb.Pubsub.DispatcherTest do
  use IslandsInterfaceWeb.ChannelCase

  alias IslandsInterface.GameContext
  alias IslandsInterfaceWeb.Pubsub.Dispatcher

  @name "test"

  @context GameContext.new(%{
             current_game: @name,
             current_user: @name
           })
  @events [
    :subscribe_to_lobby,
    :subscribe_to_game,
    :new_player,
    :handshake,
    :game_over
  ]
  @external_events [
    {:set_islands, %{"player" => @name}},
    {:guessed_coordinates,
     %{
       "row" => 1,
       "col" => 1
     }}
  ]
  @mailbox [
    :after_join_lobby,
    :after_join_game,
    {:new_player, %{"new_player" => @name}},
    {:handshake, %{}},
    {:set_islands, %{"player" => @name}},
    {:guessed_coordinates,
     %{
       "row" => 1,
       "col" => 1
     }},
    {:game_over, %{}}
  ]

  test "dispatches events to the correct callbacks" do
    Dispatcher.handle(@context, @events)
    dispatch_external_events()
    check_mailbox()
  end

  defp dispatch_external_events,
    do: spawn(fn -> Dispatcher.handle(@context, @external_events) end)

  defp check_mailbox,
    do: Enum.each(@mailbox, fn message -> assert_receive ^message end)
end
