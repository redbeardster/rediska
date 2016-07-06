-module(rediska_sup).
-behaviour(supervisor).
%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->

  Rediska = {rediska,{rediska, start_link,[]},
    permanent,2000,worker,[rediska]},

  {ok, {{one_for_one, 10, 10}, [Rediska]}}.

