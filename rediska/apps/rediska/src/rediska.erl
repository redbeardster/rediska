-module(rediska).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

-export([start_link/0]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state,{connector, queue, node_down}).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->

  Config = application:get_all_env(rediska),
  RedisHost = proplists:get_value(redis_host, Config),
  RedisPort = proplists:get_value(redis_port, Config),
  Nodes = proplists:get_value(sync_nodes, Config),

  [net_adm:ping(list_to_atom(Node)) || Node <- Nodes],
  net_kernel:monitor_nodes(true),

  io:format("Redis host: ~p, port:~p~n", [RedisHost, RedisPort]),
  {ok, Connector} = eredis:start_link(RedisHost, RedisPort, 0, ""),

  Queue = queue:new(),

  {ok, #state{connector = Connector, queue=Queue}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({nodeup, Node}, State=#state{connector=Connector, queue = Queue}) ->

  io:format("Node up: ~p~n", [Node]),
  List = queue:to_list(Queue),

  [{rediska, Node} ! {sync_data, Req} || Node <- nodes(), Req <- List],

  NewQueue = queue:new(),
  NewState=State#state{connector = Connector, node_down = false, queue = NewQueue},
  {noreply, NewState};

handle_info({nodedown, Node}, State=#state{connector=Connector}) ->

  io:format("Node down: ~p~n", [Node]),
  NewState=State#state{connector = Connector, node_down = true},
  {noreply, NewState};

handle_info({sync_data, Req}, State=#state{connector=Connector}) ->

  io:format("Sync request: ~p~n", [Req]),
  {noreply, State};


handle_info({request, Req}, State=#state{connector=Connector, node_down = Status, queue = Queue}) ->
  io:format("Got request: ~p~n", [Req]),

  case Status of
    false  ->
        [{rediska, Node} ! {sync_data, Req} || Node <- nodes()],
      NewState = State#state{connector = Connector, node_down = Status},
      {noreply, NewState};

    true ->
      io:format("Node has got down, enqueuing the request~n"),
      Q = queue:in(Req,Queue),
      io:format("Queue length is ~p~n", [queue:len(Q)]),
      NewState = State#state{connector = Connector, node_down = Status, queue = Q},
      {noreply, NewState}
  end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


