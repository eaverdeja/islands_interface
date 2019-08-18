[
  {IslandsInterface,
   deps: [],
   exports: [
     Cache,
     GameContext,
     LobbyHandler,
     BoardHandler,
     Screen
   ]},
  {IslandsInterfaceWeb, deps: [IslandsInterface], exports: [Endpoint]},
  {IslandsInterface.Application, deps: [IslandsInterface, IslandsInterfaceWeb]}
]
