%%%-------------------------------------------------------------------
%% @doc sipcall public API
%% @end
%%%-------------------------------------------------------------------

-module(sipcall_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ets:new(users_table, [set, named_table, public]),

    Dispatch = cowboy_router:compile([
        {'_', [
            {"/api/call/:userid", userid_handler, []}
        ]}
    ]),

    {ok, _} = cowboy:start_clear(
        my_http_listener,
        [{port, 8080}],
        #{env => #{dispatch => Dispatch}}
    ),

    sipcall_sup:start_link().

stop(_State) ->
    ets:delete(users_table),
    cowboy:stop_listener(my_http_listener),
    ok.

%% internal functions
