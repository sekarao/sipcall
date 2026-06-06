-module(userid_handler).

-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    Method = cowboy_req:method(Req),
    handle_request(Method, Req, State).

handle_request(<<"GET">>, Req0, State) ->
    UserId = cowboy_req:binding(userid, Req0),
    case ets:lookup(users_table, UserId) of
        [{UserId, TargetUri}] ->
            io:format("Вызов пользователя ~p~n", [UserId]),
            sip_client:call(TargetUri),
            Response = jsx:encode(#{<<"status">> => <<"calling">>,
                <<"userid">> => UserId}),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, State};
        [] ->
            io:format("Пользователь ~p не найден~n", [UserId]),
            Response = jsx:encode(#{<<"error">> => <<"User not found">>}),
            Req = cowboy_req:reply(404,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, State}
    end;


handle_request(_, Req0, State) ->
    Req = cowboy_req:reply(405,
        #{<<"content-type">> => <<"application/json">>},
        jsx:encode(#{<<"error">> => <<"Method not allowed">>}),
        Req0
    ),
    {ok, Req, State}.